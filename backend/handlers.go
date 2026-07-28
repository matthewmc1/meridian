package main

import (
	"net/http"
)

// GET /api/health — source freshness straight from staging.sync_status.
func (s *server) health(w http.ResponseWriter, r *http.Request) {
	sources, err := s.queryRows(`
		SELECT source_system, last_success, lag_seconds
		FROM staging.sync_status ORDER BY source_system`)
	if err != nil {
		s.fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "sources": sources})
}

// GET /api/signal — the Customer signal view: KPI strip, ranked customer
// table, decision queue and renewal runway. Everything is computed in the
// semantic layer; this handler only shapes it.
func (s *server) signal(w http.ResponseWriter, r *http.Request) {
	customers, err := s.queryRows(`
		SELECT customer_id, engagement_id, name, mark, sector, health_band,
		       outcomes_on_track, outcomes_total,
		       clause_breaches, clauses_at_risk, clauses_total,
		       utilisation_pct, margin_pct, velocity_delta_pct,
		       vehicle_label, CAST(acv_pennies AS BIGINT) AS acv_pennies,
		       renewal_date, renewal_days, delta_label,
		       CAST(open_risks AS BIGINT) AS open_risks,
		       CAST(crit_risks AS BIGINT) AS crit_risks
		FROM semantic.v_customer_signal
		ORDER BY CASE health_band WHEN 'at_risk' THEN 0 WHEN 'watch' THEN 1 ELSE 2 END,
		         acv_pennies DESC`)
	if err != nil {
		s.fail(w, err)
		return
	}

	sparks, err := s.queryRows(`
		SELECT engagement_id, value, window_end
		FROM core.measurement WHERE metric = 'velocity_points'
		QUALIFY ROW_NUMBER() OVER (PARTITION BY engagement_id ORDER BY window_end DESC) <= 7
		ORDER BY engagement_id, window_end`)
	if err != nil {
		s.fail(w, err)
		return
	}
	byEng := map[any][]any{}
	for _, row := range sparks {
		id := row["engagement_id"]
		byEng[id] = append(byEng[id], row["value"])
	}
	for _, c := range customers {
		c["velocity_spark"] = orEmpty(byEng[c["engagement_id"]])
	}

	kpis, err := s.queryRows(`
		SELECT
		  (SELECT CAST(SUM(acv_pennies) AS BIGINT) FROM semantic.v_customer_signal)      AS total_acv_pennies,
		  (SELECT CAST(COUNT(*) AS BIGINT) FROM semantic.v_customer_signal)              AS engagements,
		  (SELECT CAST(SUM(outcomes_on_track) AS BIGINT) FROM semantic.v_customer_signal) AS outcomes_on_track,
		  (SELECT CAST(SUM(outcomes_total) AS BIGINT) FROM semantic.v_customer_signal)   AS outcomes_total,
		  (SELECT CAST(SUM(clause_breaches) AS BIGINT) FROM semantic.v_customer_signal)  AS clause_breaches,
		  (SELECT CAST(SUM(clauses_at_risk) AS BIGINT) FROM semantic.v_customer_signal)  AS clauses_at_risk,
		  (SELECT CAST(SUM(acv_pennies) AS BIGINT) FROM semantic.v_customer_signal
		     WHERE clause_breaches > 0 OR crit_risks > 0)                                AS exposure_pennies,
		  (SELECT CAST(SUM(planned_fte - assigned_fte) AS DOUBLE) FROM core.assignment
		     WHERE planned_fte > assigned_fte)                                           AS capacity_gap_fte,
		  (SELECT CAST(COUNT(*) AS BIGINT) FROM semantic.v_customer_signal
		     WHERE renewal_days IS NOT NULL AND renewal_days <= 90)                      AS renewals_90d`)
	if err != nil {
		s.fail(w, err)
		return
	}

	decisions, err := s.queryRows(`
		SELECT je.risk_ref, je.severity, je.tone, je.title, je.scope_label, je.owner,
		       je.due_note, CAST(je.exposure_pennies AS BIGINT) AS exposure_pennies,
		       je.action_label, je.action_view
		FROM audit.journal_entry je
		WHERE je.state <> 'closed' AND je.action_label IS NOT NULL
		ORDER BY je.exposure_pennies DESC NULLS LAST`)
	if err != nil {
		s.fail(w, err)
		return
	}

	renewals, err := s.queryRows(`
		SELECT cs.customer_id, cs.name, cs.renewal_days,
		       CAST(cs.acv_pennies AS BIGINT) AS acv_pennies,
		       rm.opportunity_open, rm.note
		FROM semantic.v_customer_signal cs
		LEFT JOIN core.renewal_motion rm ON rm.engagement_id = cs.engagement_id
		WHERE cs.renewal_days IS NOT NULL AND cs.renewal_days <= 180
		ORDER BY cs.renewal_days`)
	if err != nil {
		s.fail(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"kpis": first(kpis), "customers": customers,
		"decisions": decisions, "renewals": renewals,
	})
}

// GET /api/customers/{id} — the Customer 360.
func (s *server) customer360(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	header, err := s.queryRows(`
		SELECT cs.customer_id, cs.engagement_id, cs.name, cs.mark, cs.sector, cs.health_band,
		       cs.outcomes_on_track, cs.outcomes_total, cs.clause_breaches, cs.clauses_at_risk,
		       cs.utilisation_pct, cs.margin_pct, cs.vehicle_label,
		       CAST(cs.acv_pennies AS BIGINT) AS acv_pennies, cs.renewal_date, cs.renewal_days,
		       cu.csm_name, e.delivery_lead, ci.ref AS instrument_ref,
		       CAST(ci.tcv_pennies AS BIGINT) AS tcv_pennies,
		       (SELECT CAST(SUM(CASE WHEN verdict = 'met' THEN 1 ELSE 0 END) AS BIGINT)
		          FROM semantic.v_clause_latest
		          WHERE engagement_id = cs.engagement_id AND category = 'milestone_gate') AS gates_passed,
		       (SELECT CAST(COUNT(*) AS BIGINT)
		          FROM semantic.v_clause_latest
		          WHERE engagement_id = cs.engagement_id AND category = 'milestone_gate') AS gates_total,
		       (SELECT CAST(AVG(attainment_pct) AS DOUBLE)
		          FROM semantic.v_outcome_status
		          WHERE engagement_id = cs.engagement_id) AS outcome_index,
		       (SELECT CAST(SUM(assigned_fte) AS DOUBLE) FROM core.assignment
		          WHERE engagement_id = cs.engagement_id) AS assigned_fte,
		       (SELECT CAST(SUM(planned_fte) AS DOUBLE) FROM core.assignment
		          WHERE engagement_id = cs.engagement_id) AS planned_fte
		FROM semantic.v_customer_signal cs
		JOIN core.customer cu ON cu.id = cs.customer_id
		JOIN core.engagement e ON e.id = cs.engagement_id
		LEFT JOIN core.contract_instrument ci ON ci.engagement_id = cs.engagement_id
		WHERE cs.customer_id = ?`, id)
	if err != nil {
		s.fail(w, err)
		return
	}
	if len(header) == 0 {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "unknown customer"})
		return
	}
	eng := header[0]["engagement_id"]

	outcomes, err := s.queryRows(`
		SELECT name, target_display, actual_display, status, attainment_pct,
		       measure_source, source_ref
		FROM semantic.v_outcome_status WHERE engagement_id = ? ORDER BY name`, eng)
	if err != nil {
		s.fail(w, err)
		return
	}

	clauses, err := s.queryRows(`
		SELECT clause_ref, clause_name, test_description, verdict, evidence_note,
		       money_note, evaluated_at, category, remedy_type
		FROM semantic.v_clause_latest WHERE engagement_id = ? ORDER BY clause_ref`, eng)
	if err != nil {
		s.fail(w, err)
		return
	}

	team, err := s.queryRows(`
		SELECT a.role, a.planned_fte, a.assigned_fte, a.utilisation_pct, a.flag,
		       d.name AS delivery_outcome, d.status AS delivery_status
		FROM core.assignment a
		LEFT JOIN core.delivery_outcome d ON d.id = a.delivery_outcome_id
		WHERE a.engagement_id = ? ORDER BY a.id`, eng)
	if err != nil {
		s.fail(w, err)
		return
	}

	deliveryOutcomes, err := s.queryRows(`
		SELECT d.name, d.description, d.status, d.target_date,
		       o.name AS supports_contracted,
		       (SELECT CAST(SUM(a.assigned_fte) AS DOUBLE) FROM core.assignment a
		          WHERE a.delivery_outcome_id = d.id) AS committed_fte
		FROM core.delivery_outcome d
		LEFT JOIN core.outcome o ON o.id = d.contracted_outcome_id
		WHERE d.engagement_id = ?
		ORDER BY CASE d.status WHEN 'late' THEN 0 WHEN 'at_risk' THEN 1 WHEN 'on_track' THEN 2 ELSE 3 END`, eng)
	if err != nil {
		s.fail(w, err)
		return
	}

	velocity, err := s.queryRows(`
		SELECT value, source_ref, window_end
		FROM core.measurement WHERE engagement_id = ? AND metric = 'velocity_points'
		ORDER BY window_end`, eng)
	if err != nil {
		s.fail(w, err)
		return
	}

	epics, err := s.queryRows(`
		SELECT source_key, title, state, gate_ref,
		       CASE WHEN blocked_since IS NULL THEN NULL
		            ELSE DATE_DIFF('day', CAST(blocked_since AS DATE), CURRENT_DATE) END AS blocked_days
		FROM core.work_item WHERE engagement_id = ? ORDER BY source_key DESC`, eng)
	if err != nil {
		s.fail(w, err)
		return
	}

	evidence, err := s.queryRows(`
		SELECT ev.requirement, ev.state, ev.due_at, ev.verified_at, ev.verified_by,
		       ar.kind AS artifact_kind, ar.url AS artifact_url, ar.pinned_version,
		       c.ref AS clause_ref
		FROM core.evidence ev
		LEFT JOIN core.artifact_ref ar ON ar.id = ev.artifact_id
		LEFT JOIN core.clause c ON c.id = ev.clause_id
		WHERE ev.engagement_id = ?
		ORDER BY CASE ev.state WHEN 'missing' THEN 0 WHEN 'stale' THEN 1 ELSE 2 END`, eng)
	if err != nil {
		s.fail(w, err)
		return
	}

	artifacts, err := s.queryRows(`
		SELECT kind, title, summary, status, source_system, source_ref, url,
		       version, authored_by, authored_at
		FROM core.artifact WHERE customer_id = ?
		ORDER BY kind, authored_at DESC`, id)
	if err != nil {
		s.fail(w, err)
		return
	}

	products, err := s.queryRows(`
		SELECT p.id AS product_id, p.name, p.kind, p.stage, p.launched_at,
		       p.source_url, p.source_ref, ss.name AS depends_on
		FROM core.product p
		LEFT JOIN core.shared_service ss ON ss.id = p.depends_on_service_id
		WHERE p.customer_id = ? ORDER BY p.launched_at`, id)
	if err != nil {
		s.fail(w, err)
		return
	}
	telemetry, err := s.queryRows(`
		SELECT t.product_id, t.metric, t.value, t.display_value, t.baseline,
		       t.source_system, t.source_ref, t.window_end
		FROM semantic.v_telemetry_latest t
		JOIN core.product p ON p.id = t.product_id
		WHERE p.customer_id = ? ORDER BY t.metric`, id)
	if err != nil {
		s.fail(w, err)
		return
	}
	byProduct := map[any][]any{}
	for _, t := range telemetry {
		byProduct[t["product_id"]] = append(byProduct[t["product_id"]], t)
	}
	for _, p := range products {
		p["telemetry"] = orEmpty(byProduct[p["product_id"]])
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"header": header[0], "outcomes": outcomes, "clauses": clauses,
		"team": team, "delivery_outcomes": deliveryOutcomes,
		"velocity": velocity, "epics": epics, "evidence": evidence,
		"artifacts": artifacts, "products": products,
	})
}

// GET /api/journal — append-only risk log, newest first.
func (s *server) journal(w http.ResponseWriter, r *http.Request) {
	entries, err := s.queryRows(`
		SELECT id, risk_ref, severity, tone, title, body, scope_label, cluster_id,
		       movement_from, movement_to, state, owner, due_note, created_at, author
		FROM audit.journal_entry ORDER BY created_at DESC`)
	if err != nil {
		s.fail(w, err)
		return
	}
	links, err := s.queryRows(`
		SELECT journal_id, text, tone FROM audit.journal_entry_link`)
	if err != nil {
		s.fail(w, err)
		return
	}
	byEntry := map[any][]any{}
	for _, l := range links {
		byEntry[l["journal_id"]] = append(byEntry[l["journal_id"]], l)
	}
	for _, e := range entries {
		e["links"] = orEmpty(byEntry[e["id"]])
	}
	writeJSON(w, http.StatusOK, map[string]any{"entries": entries})
}

// GET /api/correlation — active vulnerability cluster: blast radius with
// contractual re-scoring, the shared-service matrix, correlated symptoms.
func (s *server) correlation(w http.ResponseWriter, r *http.Request) {
	vuln, err := s.queryRows(`
		SELECT v.id, v.ref, v.title, v.description, v.disclosed_at, v.fixed_in_version,
		       s.name AS service_name
		FROM core.vulnerability v
		JOIN core.shared_service s ON s.id = v.service_id
		ORDER BY v.disclosed_at DESC LIMIT 1`)
	if err != nil {
		s.fail(w, err)
		return
	}
	if len(vuln) == 0 {
		writeJSON(w, http.StatusOK, map[string]any{"vulnerability": nil})
		return
	}
	vulnID := vuln[0]["id"]

	affected, err := s.queryRows(`
		SELECT customer_id, customer_name, mark, version, env_label, exposure, impact,
		       security_clause_ref, security_clause_name, remedy_type,
		       CAST(acv_pennies AS BIGINT) AS acv_pennies
		FROM semantic.v_blast_radius WHERE vulnerability_id = ?
		ORDER BY CASE impact WHEN 'impacted' THEN 0 WHEN 'potentially_impacted' THEN 1 ELSE 2 END,
		         acv_pennies DESC`, vulnID)
	if err != nil {
		s.fail(w, err)
		return
	}

	matrix, err := s.queryRows(`
		SELECT s.name AS service, cu.mark, cu.name AS customer_name,
		       CASE WHEN d.id IS NULL THEN 'none'
		            WHEN av.version IS NOT NULL THEN 'vulnerable'
		            WHEN d.version <> s.current_version THEN 'drift'
		            ELSE 'patched' END AS status
		FROM core.shared_service s
		CROSS JOIN core.customer cu
		LEFT JOIN core.deployment d ON d.service_id = s.id AND d.customer_id = cu.id
		LEFT JOIN (
		  SELECT DISTINCT av.version, v.service_id
		  FROM core.vulnerability_affected_version av
		  JOIN core.vulnerability v ON v.id = av.vulnerability_id
		) av ON av.service_id = s.id AND av.version = d.version
		ORDER BY s.name, cu.name`)
	if err != nil {
		s.fail(w, err)
		return
	}

	symptoms, err := s.queryRows(`
		SELECT t.source_key, t.summary, t.fingerprint, t.opened_at,
		       cu.name AS customer_name, cu.mark,
		       (SELECT CAST(COUNT(DISTINCT t2.customer_id) AS BIGINT)
		          FROM core.ticket t2 WHERE t2.fingerprint = t.fingerprint) AS customers_sharing
		FROM core.ticket t
		JOIN core.customer cu ON cu.id = t.customer_id
		ORDER BY customers_sharing DESC, t.opened_at`)
	if err != nil {
		s.fail(w, err)
		return
	}

	rationale, err := s.queryRows(`
		SELECT customer_id, evidence_kind, rationale, confidence,
		       evidence_label, evidence_source, artifact_url, artifact_kind
		FROM semantic.v_impact_rationale
		WHERE subject_kind = 'vulnerability' AND subject_id = ?
		ORDER BY customer_id,
		         CASE confidence WHEN 'confirmed' THEN 0 WHEN 'probable' THEN 1 ELSE 2 END`, vulnID)
	if err != nil {
		s.fail(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"vulnerability": vuln[0], "affected": affected,
		"matrix": matrix, "symptoms": symptoms, "rationale": rationale,
	})
}

// GET /api/rag — RAG board: band movement vs last snapshot, discussion topics
// from the journal, and incidents bubbling toward severity.
func (s *server) rag(w http.ResponseWriter, r *http.Request) {
	movement, err := s.queryRows(`
		SELECT customer_id, name, mark, sector, health_band, prev_band, snapshot_date,
		       CAST(breaches_delta AS BIGINT) AS breaches_delta,
		       CAST(at_risk_delta AS BIGINT) AS at_risk_delta,
		       CAST(outcomes_delta AS BIGINT) AS outcomes_delta,
		       CAST(risks_delta AS BIGINT) AS risks_delta,
		       util_delta, velocity_delta_pct,
		       CAST(clause_breaches AS BIGINT) AS clause_breaches,
		       CAST(outcomes_on_track AS BIGINT) AS outcomes_on_track,
		       CAST(outcomes_total AS BIGINT) AS outcomes_total,
		       utilisation_pct, CAST(open_risks AS BIGINT) AS open_risks,
		       CAST(acv_pennies AS BIGINT) AS acv_pennies, renewal_days
		FROM semantic.v_rag_movement
		ORDER BY CASE health_band WHEN 'at_risk' THEN 0 WHEN 'watch' THEN 1 ELSE 2 END,
		         CASE WHEN health_band <> prev_band THEN 0 ELSE 1 END,
		         acv_pennies DESC`)
	if err != nil {
		s.fail(w, err)
		return
	}

	topics, err := s.queryRows(`
		SELECT jc.customer_id, je.risk_ref, je.title, je.tone, je.state,
		       je.due_note, je.created_at
		FROM audit.journal_entry je
		JOIN audit.journal_entry_customer jc ON jc.journal_id = je.id
		WHERE je.state <> 'closed'
		ORDER BY je.created_at DESC`)
	if err != nil {
		s.fail(w, err)
		return
	}
	byCustomer := map[any][]any{}
	for _, t := range topics {
		byCustomer[t["customer_id"]] = append(byCustomer[t["customer_id"]], t)
	}
	for _, m := range movement {
		m["topics"] = orEmpty(byCustomer[m["customer_id"]])
	}

	bubbling, err := s.queryRows(`
		SELECT customer_id, customer_name, mark, source_key, summary, fingerprint,
		       status, priority,
		       CAST(comment_count AS BIGINT) AS comment_count,
		       CAST(reopen_count AS BIGINT) AS reopen_count,
		       CAST(participant_count AS BIGINT) AS participant_count,
		       CAST(customers_sharing AS BIGINT) AS customers_sharing,
		       bubble_score, opened_at, last_activity_at
		FROM semantic.v_bubbling_incidents
		ORDER BY bubble_score DESC
		LIMIT 12`)
	if err != nil {
		s.fail(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"movement": movement, "bubbling": bubbling,
	})
}

func first(rows []map[string]any) map[string]any {
	if len(rows) > 0 {
		return rows[0]
	}
	return map[string]any{}
}

func orEmpty(v []any) []any {
	if v == nil {
		return []any{}
	}
	return v
}
