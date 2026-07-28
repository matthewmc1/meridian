-- ============================================================================
-- Meridian data lake — DuckDB now, BigQuery later.
--
-- Portability rules (enforced by review):
--   * Types restricted to the BQ-mappable set:
--       VARCHAR→STRING, BIGINT→INT64, DOUBLE→FLOAT64, BOOLEAN→BOOL,
--       TIMESTAMP→TIMESTAMP, DATE→DATE, JSON→JSON
--   * No sequences / auto-increment (BQ has none): ids are app-generated strings.
--   * No arrays or structs in base tables: join tables instead.
--   * Views use only standard SQL + QUALIFY (supported by both engines).
--   * DuckDB schemas map to BQ datasets: staging / core / semantic / audit.
--   * Money is BIGINT pennies. Percentages are DOUBLE 0–100.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS semantic;

-- ----------------------------------------------------------------------------
-- STAGING — raw, immutable, append-only. One table for every source.
-- BQ note: partition on extracted_at, cluster on (source_system, source_type).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS staging.source_record (
  id             VARCHAR NOT NULL,          -- app-generated uuid
  source_system  VARCHAR NOT NULL,          -- salesforce|workday|jira|jsm|confluence|gdrive|deployinv|seed
  source_type    VARCHAR NOT NULL,
  source_id      VARCHAR NOT NULL,
  payload        JSON    NOT NULL,
  payload_hash   VARCHAR NOT NULL,
  extracted_at   TIMESTAMP NOT NULL,
  batch_id       VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.sync_status (
  source_system  VARCHAR NOT NULL,
  last_success   TIMESTAMP,
  last_error     VARCHAR,
  lag_seconds    BIGINT
);

-- ----------------------------------------------------------------------------
-- CORE — canonical entities. Projected from staging by connectors/projectors.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.customer (
  id        VARCHAR NOT NULL,
  name      VARCHAR NOT NULL,
  mark      VARCHAR NOT NULL,               -- 2-letter monogram shown in UI
  sector    VARCHAR,
  csm_name  VARCHAR
);

CREATE TABLE IF NOT EXISTS core.engagement (
  id            VARCHAR NOT NULL,
  customer_id   VARCHAR NOT NULL,
  name          VARCHAR NOT NULL,
  delivery_lead VARCHAR,
  status        VARCHAR NOT NULL            -- active|closing|closed
);

-- Identity crosswalk: every native id that means "this customer/engagement".
CREATE TABLE IF NOT EXISTS core.crosswalk (
  id            VARCHAR NOT NULL,
  entity_kind   VARCHAR NOT NULL,           -- customer|engagement
  entity_id     VARCHAR NOT NULL,
  source_system VARCHAR NOT NULL,
  source_type   VARCHAR NOT NULL,           -- sf_account|jira_project|jsm_org|confluence_space|gdrive_drive|wd_project
  source_id     VARCHAR NOT NULL,
  confidence    VARCHAR NOT NULL            -- manual|high|review
);

-- Ingested records that matched no crosswalk row: the data-quality queue.
CREATE TABLE IF NOT EXISTS core.unmapped_record (
  id            VARCHAR NOT NULL,
  source_system VARCHAR NOT NULL,
  source_type   VARCHAR NOT NULL,
  source_id     VARCHAR NOT NULL,
  first_seen    TIMESTAMP NOT NULL,
  note          VARCHAR
);

CREATE TABLE IF NOT EXISTS core.contract_instrument (
  id             VARCHAR NOT NULL,
  engagement_id  VARCHAR NOT NULL,
  ref            VARCHAR NOT NULL,          -- 'MSA-2023-041', 'SOW-14'
  kind           VARCHAR NOT NULL,          -- msa|sow|call_off|framework|retainer|managed
  vehicle_label  VARCHAR NOT NULL,          -- display string, e.g. 'MSA + SOW-14 · fixed price'
  acv_pennies    BIGINT NOT NULL,
  tcv_pennies    BIGINT,
  currency       VARCHAR NOT NULL,
  renewal_date   DATE,
  notice_days    BIGINT,
  delta_label    VARCHAR                    -- e.g. '+£0.4m CO' until change orders are modelled
);

CREATE TABLE IF NOT EXISTS core.clause (
  id                    VARCHAR NOT NULL,
  instrument_id         VARCHAR NOT NULL,
  engagement_id         VARCHAR NOT NULL,
  ref                   VARCHAR NOT NULL,   -- '§7.2'
  name                  VARCHAR NOT NULL,
  test_description      VARCHAR NOT NULL,   -- human-readable test
  spec                  JSON NOT NULL,      -- machine-checkable spec (versioned)
  spec_version          BIGINT NOT NULL,
  tier                  VARCHAR NOT NULL,   -- auto|assisted|manual_attest
  category              VARCHAR NOT NULL,   -- milestone_gate|sla|change_control|personnel|security_remediation|reporting|benefit_case
  remedy_type           VARCHAR,            -- milestone_hold|sla_credit|uncapped_credit
  remedy_amount_pennies BIGINT,
  check_cadence_minutes BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.outcome (
  id             VARCHAR NOT NULL,
  engagement_id  VARCHAR NOT NULL,
  name           VARCHAR NOT NULL,
  target_value   DOUBLE NOT NULL,
  target_display VARCHAR NOT NULL,          -- '99.5%', '90 sites'
  direction      VARCHAR NOT NULL,          -- gte|lte
  window_kind    VARCHAR NOT NULL,          -- rolling|period|cumulative
  window_days    BIGINT,
  measure_metric VARCHAR NOT NULL,          -- joins measurement.metric
  measure_source VARCHAR NOT NULL           -- jira|jsm|workday|salesforce|derived
);

-- Every number the platform believes, with its window and provenance.
-- BQ note: partition on window_end, cluster on (engagement_id, metric).
CREATE TABLE IF NOT EXISTS core.measurement (
  id            VARCHAR NOT NULL,
  engagement_id VARCHAR NOT NULL,
  metric        VARCHAR NOT NULL,           -- crash_free_rate|telemetry_sites|velocity_points|utilisation_pct|margin_pct|csat|...
  value         DOUBLE NOT NULL,
  display_value VARCHAR,                    -- optional formatted form
  window_start  TIMESTAMP NOT NULL,
  window_end    TIMESTAMP NOT NULL,
  source_system VARCHAR NOT NULL,
  source_ref    VARCHAR                     -- native record ref, e.g. 'NWR-401', 'LRN-2026'
);

CREATE TABLE IF NOT EXISTS core.work_item (
  id            VARCHAR NOT NULL,
  engagement_id VARCHAR NOT NULL,
  source_key    VARCHAR NOT NULL,           -- 'NWR-482'
  kind          VARCHAR NOT NULL,           -- epic|story|jsm_request
  title         VARCHAR NOT NULL,
  state         VARCHAR NOT NULL,           -- not_started|in_progress|gate|done
  gate_ref      VARCHAR,                    -- clause ref it gates, if any
  blocked_since TIMESTAMP,
  delivery_outcome_id VARCHAR               -- delivery outcome this work drives
);

-- Platform gaps: capabilities the PLATFORM is missing or hasn't shipped yet
-- that block client work. Distinct from client risks — a gap is ours to fix,
-- and one gap can block many clients (that reach is what gets it prioritised).
CREATE TABLE IF NOT EXISTS core.platform_gap (
  id          VARCHAR NOT NULL,
  name        VARCHAR NOT NULL,
  description VARCHAR NOT NULL,
  status      VARCHAR NOT NULL,             -- backlog|in_design|in_progress|done
  eta         DATE,
  owner       VARCHAR
);

CREATE TABLE IF NOT EXISTS core.platform_gap_customer (
  gap_id        VARCHAR NOT NULL,
  customer_id   VARCHAR NOT NULL,
  blocking_note VARCHAR NOT NULL,           -- what it blocks for THIS client
  linked_ref    VARCHAR                     -- work item / ticket / FR it blocks
);

-- Definitions of derived measures, served from the lake so the console can
-- explain its own numbers. One row per definition key.
CREATE TABLE IF NOT EXISTS core.definition (
  key        VARCHAR NOT NULL,              -- 'velocity', 'delivery_risk', …
  title      VARCHAR NOT NULL,
  definition VARCHAR NOT NULL,              -- prose a CSM can read to a client
  formula    VARCHAR,                       -- the computable rule
  inputs     VARCHAR                        -- where the numbers come from
);

-- Delivery outcomes: what the team's capacity is actually driving. Distinct
-- from contracted outcomes (core.outcome) — a delivery outcome is operational
-- ("wave 3 live across 16 depots"), and MAY support a contracted outcome.
CREATE TABLE IF NOT EXISTS core.delivery_outcome (
  id                    VARCHAR NOT NULL,
  engagement_id         VARCHAR NOT NULL,
  name                  VARCHAR NOT NULL,
  description           VARCHAR,
  status                VARCHAR NOT NULL,   -- on_track|at_risk|late|done
  target_date           DATE,
  contracted_outcome_id VARCHAR             -- core.outcome it supports, if any
);

CREATE TABLE IF NOT EXISTS core.assignment (
  id             VARCHAR NOT NULL,
  engagement_id  VARCHAR NOT NULL,
  role           VARCHAR NOT NULL,          -- 'Platform engineering ×6'
  planned_fte    DOUBLE NOT NULL,
  assigned_fte   DOUBLE NOT NULL,
  utilisation_pct DOUBLE NOT NULL,
  flag           VARCHAR,                   -- 'ATTRITION ×2' | 'OPEN ROLE ×1'
  delivery_outcome_id VARCHAR               -- what this capacity is committed to
);

-- Polymorphic pointer into Jira / Confluence / Drive. Version-pinned when verified.
CREATE TABLE IF NOT EXISTS core.artifact_ref (
  id             VARCHAR NOT NULL,
  kind           VARCHAR NOT NULL,          -- jira_attachment|confluence_page|gdrive_file
  source_id      VARCHAR NOT NULL,
  pinned_version VARCHAR,                   -- confluence version / drive headRevisionId
  url            VARCHAR NOT NULL,
  content_hash   VARCHAR
);

CREATE TABLE IF NOT EXISTS core.evidence (
  id            VARCHAR NOT NULL,
  engagement_id VARCHAR NOT NULL,
  clause_id     VARCHAR,                    -- clause this satisfies, if any
  requirement   VARCHAR NOT NULL,           -- uat_pack|release_note|signed_benefit_case|runbook|signed_co|crash_report
  artifact_id   VARCHAR,                    -- NULL ⇒ missing (first-class negative record)
  state         VARCHAR NOT NULL,           -- missing|attached|verified|stale
  due_at        TIMESTAMP,
  verified_at   TIMESTAMP,
  verified_by   VARCHAR
);

-- Correlation backbone -------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.shared_service (
  id              VARCHAR NOT NULL,
  name            VARCHAR NOT NULL,
  current_version VARCHAR
);

CREATE TABLE IF NOT EXISTS core.deployment (
  id          VARCHAR NOT NULL,
  service_id  VARCHAR NOT NULL,
  customer_id VARCHAR NOT NULL,
  version     VARCHAR NOT NULL,
  environment VARCHAR NOT NULL,             -- prod|staging
  env_label   VARCHAR,                      -- 'prod + 2 regional'
  exposure    VARCHAR NOT NULL              -- internet_facing|internal|none
);

CREATE TABLE IF NOT EXISTS core.vulnerability (
  id               VARCHAR NOT NULL,
  ref              VARCHAR NOT NULL,        -- 'CVE-2026-1180'
  service_id       VARCHAR NOT NULL,
  title            VARCHAR NOT NULL,
  description      VARCHAR,
  disclosed_at     TIMESTAMP NOT NULL,
  fixed_in_version VARCHAR
);

-- Join table instead of an array column (BQ-portable, index-friendly).
CREATE TABLE IF NOT EXISTS core.vulnerability_affected_version (
  vulnerability_id VARCHAR NOT NULL,
  version          VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS core.ticket (
  id            VARCHAR NOT NULL,
  customer_id   VARCHAR NOT NULL,
  source_key    VARCHAR NOT NULL,           -- JSM issue key
  request_type  VARCHAR,
  summary       VARCHAR NOT NULL,
  fingerprint   VARCHAR,                    -- computed symptom signature
  cluster_id    VARCHAR,
  opened_at     TIMESTAMP NOT NULL,
  status        VARCHAR NOT NULL,           -- open|waiting_client|waiting_us|resolved
  priority      VARCHAR NOT NULL,           -- low|medium|high
  comment_count BIGINT NOT NULL,            -- back-and-forth volume (JSM)
  reopen_count  BIGINT NOT NULL,            -- times reopened after resolution
  participant_count BIGINT NOT NULL,        -- distinct people in the thread
  last_activity_at  TIMESTAMP
);

-- Client artifact library: everything we hold about a customer, catalogued and
-- linked to its source of truth. Missing expected artifacts are detectable by
-- comparing against the per-contract-type checklist (a control, not a query).
CREATE TABLE IF NOT EXISTS core.artifact (
  id            VARCHAR NOT NULL,
  customer_id   VARCHAR NOT NULL,
  engagement_id VARCHAR,
  kind          VARCHAR NOT NULL,           -- site_visit_report|target_architecture|capacity_plan|doc|runbook|incident_review|feature_request|accelerator
  title         VARCHAR NOT NULL,
  summary       VARCHAR,
  status        VARCHAR NOT NULL,           -- draft|in_review|final|approved|open|shipped|adopted
  source_system VARCHAR NOT NULL,           -- confluence|gdrive|jira|jsm
  source_ref    VARCHAR NOT NULL,           -- native id (page id, file id, issue key)
  url           VARCHAR NOT NULL,
  version       VARCHAR,
  authored_by   VARCHAR,
  authored_at   TIMESTAMP NOT NULL
);

-- Products the client has launched with us, with a link back to their source.
CREATE TABLE IF NOT EXISTS core.product (
  id            VARCHAR NOT NULL,
  customer_id   VARCHAR NOT NULL,
  engagement_id VARCHAR,
  name          VARCHAR NOT NULL,
  kind          VARCHAR NOT NULL,           -- mobile_app|api|data_pipeline|portal|platform
  stage         VARCHAR NOT NULL,           -- pilot|beta|ga|sunset
  launched_at   DATE,
  depends_on_service_id VARCHAR,            -- shared_service this product runs on (correlation input)
  source_url    VARCHAR,                    -- repo / release page
  source_ref    VARCHAR                     -- release tag / build id
);

-- Product telemetry: how the client's products actually perform.
-- BQ note: partition on window_end, cluster on (product_id, metric).
CREATE TABLE IF NOT EXISTS core.telemetry (
  id            VARCHAR NOT NULL,
  product_id    VARCHAR NOT NULL,
  metric        VARCHAR NOT NULL,           -- p99_latency_ms|error_rate_pct|uptime_pct|mau|crash_free_pct|throughput_rps
  value         DOUBLE NOT NULL,
  display_value VARCHAR,
  baseline      DOUBLE,                     -- optional baseline for the same metric
  window_start  TIMESTAMP NOT NULL,
  window_end    TIMESTAMP NOT NULL,
  source_system VARCHAR NOT NULL,
  source_ref    VARCHAR
);

CREATE TABLE IF NOT EXISTS core.renewal_motion (
  engagement_id    VARCHAR NOT NULL,
  opportunity_open BOOLEAN NOT NULL,
  note             VARCHAR
);

-- ----------------------------------------------------------------------------
-- AUDIT — evaluations and the append-only journal.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit.clause_evaluation (
  id           VARCHAR NOT NULL,
  clause_id    VARCHAR NOT NULL,
  spec_version BIGINT NOT NULL,
  evaluated_at TIMESTAMP NOT NULL,
  verdict      VARCHAR NOT NULL,            -- met|at_risk|breach|cannot_evaluate
  evidence_note VARCHAR,                    -- what the check saw, e.g. 'Rolling 30d: 99.1%'
  money_note   VARCHAR,                     -- '£340k held', '£62k credit', 'uncapped'
  detail       JSON NOT NULL
);

CREATE TABLE IF NOT EXISTS audit.journal_entry (
  id            VARCHAR NOT NULL,
  risk_ref      VARCHAR NOT NULL,           -- 'RSK-1180'
  severity      VARCHAR NOT NULL,           -- P1|P2|CLOSED
  tone          VARCHAR NOT NULL,           -- crit|warn|good  (display severity)
  title         VARCHAR NOT NULL,
  body          VARCHAR NOT NULL,
  scope_label   VARCHAR NOT NULL,           -- 'Northwind Rail' | 'Cross-customer · 3 clients'
  cluster_id    VARCHAR,
  movement_from VARCHAR NOT NULL,
  movement_to   VARCHAR NOT NULL,
  state         VARCHAR NOT NULL,           -- open|escalated|closed
  owner         VARCHAR NOT NULL,
  due_note      VARCHAR,
  exposure_pennies BIGINT,
  action_label  VARCHAR,                    -- decision-queue button text, if it needs a decision
  action_view   VARCHAR,                    -- console view the action deep-links to
  created_at    TIMESTAMP NOT NULL,
  author        VARCHAR NOT NULL
);

-- Weekly snapshot of the customer signal, written by a scheduled job. The RAG
-- board diffs the live signal against the latest snapshot to answer
-- "what changed since we last talked about this customer".
CREATE TABLE IF NOT EXISTS audit.signal_snapshot (
  snapshot_date      DATE NOT NULL,
  customer_id        VARCHAR NOT NULL,
  health_band        VARCHAR NOT NULL,
  outcomes_on_track  BIGINT,
  outcomes_total     BIGINT,
  clause_breaches    BIGINT,
  clauses_at_risk    BIGINT,
  utilisation_pct    DOUBLE,
  velocity_delta_pct DOUBLE,
  open_risks         BIGINT
);

-- Impact evidence: WHY we believe a customer is (potentially) impacted by a
-- subject (vulnerability, risk, cluster). Every row points at a concrete
-- source record — a deployment, an artifact, a ticket, or telemetry — so the
-- claim is always traceable to source material.
CREATE TABLE IF NOT EXISTS audit.impact_evidence (
  id            VARCHAR NOT NULL,
  subject_kind  VARCHAR NOT NULL,           -- vulnerability|risk|cluster
  subject_id    VARCHAR NOT NULL,
  customer_id   VARCHAR NOT NULL,
  evidence_kind VARCHAR NOT NULL,           -- deployment|artifact|ticket|telemetry
  evidence_id   VARCHAR NOT NULL,
  rationale     VARCHAR NOT NULL,           -- one sentence a human can defend
  confidence    VARCHAR NOT NULL,           -- confirmed|probable|possible
  created_at    TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS audit.journal_entry_customer (
  journal_id  VARCHAR NOT NULL,
  customer_id VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS audit.journal_entry_link (
  journal_id VARCHAR NOT NULL,
  text       VARCHAR NOT NULL,              -- '§7.2 breach', 'Jira NWR-482'
  tone       VARCHAR NOT NULL               -- crit|warn|good|muted
);

-- ----------------------------------------------------------------------------
-- SEMANTIC — derived, versioned, explainable. Views only; no stored numbers.
-- ----------------------------------------------------------------------------

-- Latest evaluation per clause.
CREATE OR REPLACE VIEW semantic.v_clause_latest AS
SELECT ce.*, c.engagement_id, c.ref AS clause_ref, c.name AS clause_name,
       c.test_description, c.category, c.remedy_type, c.remedy_amount_pennies
FROM audit.clause_evaluation ce
JOIN core.clause c ON c.id = ce.clause_id
QUALIFY ROW_NUMBER() OVER (PARTITION BY ce.clause_id ORDER BY ce.evaluated_at DESC) = 1;

-- Latest measurement per engagement+metric.
CREATE OR REPLACE VIEW semantic.v_measure_latest AS
SELECT *
FROM core.measurement
QUALIFY ROW_NUMBER() OVER (PARTITION BY engagement_id, metric ORDER BY window_end DESC) = 1;

-- Outcome status: latest measurement vs target.
CREATE OR REPLACE VIEW semantic.v_outcome_status AS
SELECT o.id AS outcome_id, o.engagement_id, o.name, o.target_display, o.measure_source,
       m.display_value AS actual_display, m.value AS actual_value, o.target_value, o.direction,
       m.source_ref,
       CASE
         WHEN m.value IS NULL THEN 'unknown'
         WHEN (o.direction = 'gte' AND m.value >= o.target_value)
           OR (o.direction = 'lte' AND m.value <= o.target_value) THEN 'met'
         WHEN (o.direction = 'gte' AND m.value >= o.target_value * 0.9)
           OR (o.direction = 'lte' AND m.value <= o.target_value * 1.1) THEN 'behind'
         ELSE 'at_risk'
       END AS status,
       CASE
         WHEN m.value IS NULL THEN 0.0
         WHEN o.direction = 'gte' THEN LEAST(100.0, 100.0 * m.value / o.target_value)
         ELSE LEAST(100.0, 100.0 * o.target_value / NULLIF(m.value, 0))
       END AS attainment_pct
FROM core.outcome o
LEFT JOIN semantic.v_measure_latest m
  ON m.engagement_id = o.engagement_id AND m.metric = o.measure_metric;

-- Velocity trend: latest sprint vs mean of the 6 before it.
CREATE OR REPLACE VIEW semantic.v_velocity_trend AS
WITH ranked AS (
  SELECT engagement_id, value, window_end,
         ROW_NUMBER() OVER (PARTITION BY engagement_id ORDER BY window_end DESC) AS rn
  FROM core.measurement WHERE metric = 'velocity_points'
)
SELECT cur.engagement_id,
       cur.value AS latest_points,
       AVG(prev.value) AS mean_prev6,
       CASE WHEN AVG(prev.value) IS NULL OR AVG(prev.value) = 0 THEN 0.0
            ELSE ROUND(100.0 * (cur.value - AVG(prev.value)) / AVG(prev.value), 0)
       END AS delta_pct
FROM ranked cur
LEFT JOIN ranked prev
  ON prev.engagement_id = cur.engagement_id AND prev.rn BETWEEN 2 AND 7
WHERE cur.rn = 1
GROUP BY cur.engagement_id, cur.value;

-- Per-engagement rollup feeding the health band.
CREATE OR REPLACE VIEW semantic.v_engagement_rollup AS
SELECT e.id AS engagement_id, e.customer_id,
       COALESCE(cl.breaches, 0)  AS clause_breaches,
       COALESCE(cl.at_risk, 0)   AS clauses_at_risk,
       COALESCE(cl.total, 0)     AS clauses_total,
       COALESCE(oc.on_track, 0)  AS outcomes_on_track,
       COALESCE(oc.total, 0)     AS outcomes_total,
       um.value                  AS utilisation_pct,
       mm.value                  AS margin_pct,
       vt.delta_pct              AS velocity_delta_pct
FROM core.engagement e
LEFT JOIN (
  SELECT engagement_id,
         SUM(CASE WHEN verdict = 'breach'  THEN 1 ELSE 0 END) AS breaches,
         SUM(CASE WHEN verdict = 'at_risk' THEN 1 ELSE 0 END) AS at_risk,
         COUNT(*) AS total
  FROM semantic.v_clause_latest GROUP BY engagement_id
) cl ON cl.engagement_id = e.id
LEFT JOIN (
  SELECT engagement_id,
         SUM(CASE WHEN status = 'met' THEN 1 ELSE 0 END) AS on_track,
         COUNT(*) AS total
  FROM semantic.v_outcome_status GROUP BY engagement_id
) oc ON oc.engagement_id = e.id
LEFT JOIN semantic.v_measure_latest um
  ON um.engagement_id = e.id AND um.metric = 'utilisation_pct'
LEFT JOIN semantic.v_measure_latest mm
  ON mm.engagement_id = e.id AND mm.metric = 'margin_pct'
LEFT JOIN semantic.v_velocity_trend vt ON vt.engagement_id = e.id
WHERE e.status = 'active';

-- Health band, definition v1 (rule-based, documented; a CSM must be able to
-- defend the band in front of a client):
--   at_risk : ≥2 breaches, or a breach alongside <50% outcome attainment
--   watch   : any breach, any at-risk clause, sustained util >100%, or util <75% (bench)
--   on_track: otherwise
CREATE OR REPLACE VIEW semantic.v_customer_signal AS
SELECT cu.id AS customer_id, cu.name, cu.mark, cu.sector,
       r.engagement_id,
       CASE
         WHEN r.clause_breaches >= 2
           OR (r.clause_breaches >= 1
               AND r.outcomes_on_track * 2 < r.outcomes_total)        THEN 'at_risk'
         WHEN r.clause_breaches >= 1 OR r.clauses_at_risk >= 1
           OR COALESCE(r.utilisation_pct, 100) > 100
           OR COALESCE(r.utilisation_pct, 100) < 75                   THEN 'watch'
         ELSE 'on_track'
       END AS health_band,
       r.outcomes_on_track, r.outcomes_total,
       r.clause_breaches, r.clauses_at_risk, r.clauses_total,
       r.utilisation_pct, r.margin_pct, r.velocity_delta_pct,
       ci.vehicle_label, ci.acv_pennies, ci.renewal_date, ci.delta_label,
       DATE_DIFF('day', CURRENT_DATE, ci.renewal_date) AS renewal_days,  -- BQ: DATE_DIFF(ci.renewal_date, CURRENT_DATE(), DAY)
       COALESCE(j.open_risks, 0) AS open_risks,
       COALESCE(j.crit_risks, 0) AS crit_risks
FROM core.customer cu
JOIN semantic.v_engagement_rollup r ON r.customer_id = cu.id
LEFT JOIN core.contract_instrument ci ON ci.engagement_id = r.engagement_id
LEFT JOIN (
  SELECT jc.customer_id,
         COUNT(*) AS open_risks,
         SUM(CASE WHEN je.tone = 'crit' THEN 1 ELSE 0 END) AS crit_risks
  FROM audit.journal_entry je
  JOIN audit.journal_entry_customer jc ON jc.journal_id = je.id
  WHERE je.state <> 'closed'
  GROUP BY jc.customer_id
) j ON j.customer_id = cu.id;

-- Client workload: EVERYTHING in flight for a client, grouped by status —
-- Jira delivery work and JSM service tickets in one list. Deliberately not a
-- sprint view: the client conversation is "what state is my work in", not
-- "which sprint is it parked in". Blocked is derived, never self-reported.
CREATE OR REPLACE VIEW semantic.v_client_workload AS
SELECT e.customer_id, w.source_key, 'jira' AS source_system, w.kind, w.title,
       CASE WHEN w.blocked_since IS NOT NULL AND w.state <> 'done' THEN 'blocked'
            ELSE w.state END AS status,
       w.gate_ref,
       CASE WHEN w.blocked_since IS NULL THEN NULL
            ELSE DATE_DIFF('day', CAST(w.blocked_since AS DATE), CURRENT_DATE) END AS blocked_days,
       d.name AS delivery_outcome,
       NULL AS priority
FROM core.work_item w
JOIN core.engagement e ON e.id = w.engagement_id
LEFT JOIN core.delivery_outcome d ON d.id = w.delivery_outcome_id
UNION ALL
SELECT t.customer_id, t.source_key, 'jsm', COALESCE(t.request_type, 'request'), t.summary,
       t.status, NULL, NULL, NULL, t.priority
FROM core.ticket t;

-- RAG movement: live signal vs most recent snapshot — the deltas are the
-- conversation starters ("what changed this week").
CREATE OR REPLACE VIEW semantic.v_rag_movement AS
SELECT cs.customer_id, cs.name, cs.mark, cs.sector,
       cs.health_band, ss.health_band AS prev_band, ss.snapshot_date,
       cs.clause_breaches   - COALESCE(ss.clause_breaches, 0)  AS breaches_delta,
       cs.clauses_at_risk   - COALESCE(ss.clauses_at_risk, 0)  AS at_risk_delta,
       cs.outcomes_on_track - COALESCE(ss.outcomes_on_track, 0) AS outcomes_delta,
       cs.open_risks        - COALESCE(ss.open_risks, 0)       AS risks_delta,
       cs.utilisation_pct   - ss.utilisation_pct               AS util_delta,
       cs.velocity_delta_pct,
       cs.clause_breaches, cs.clauses_at_risk, cs.outcomes_on_track, cs.outcomes_total,
       cs.utilisation_pct, cs.open_risks, cs.acv_pennies, cs.renewal_days
FROM semantic.v_customer_signal cs
LEFT JOIN (
  SELECT * FROM audit.signal_snapshot
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY snapshot_date DESC) = 1
) ss ON ss.customer_id = cs.customer_id;

-- Bubbling incidents: tickets whose churn says "this wants to become a severe
-- incident" — heavy back-and-forth, reopens, many participants, or the same
-- symptom fingerprint appearing at other customers. Score is documented here
-- and shown with its reasons in the UI; tune the weights in one place.
CREATE OR REPLACE VIEW semantic.v_bubbling_incidents AS
SELECT t.id, t.customer_id, cu.name AS customer_name, cu.mark,
       t.source_key, t.summary, t.fingerprint, t.status, t.priority,
       t.comment_count, t.reopen_count, t.participant_count,
       t.opened_at, t.last_activity_at,
       sh.customers_sharing,
       CAST(t.comment_count * 1.0
          + t.reopen_count * 6.0
          + t.participant_count * 2.0
          + CASE WHEN sh.customers_sharing > 1 THEN 10.0 ELSE 0.0 END
          + CASE t.priority WHEN 'high' THEN 8.0 WHEN 'medium' THEN 3.0 ELSE 0.0 END
         AS DOUBLE) AS bubble_score
FROM core.ticket t
JOIN core.customer cu ON cu.id = t.customer_id
JOIN (
  SELECT fingerprint, COUNT(DISTINCT customer_id) AS customers_sharing
  FROM core.ticket GROUP BY fingerprint
) sh ON sh.fingerprint = t.fingerprint
WHERE t.status <> 'resolved';

-- Latest telemetry per product+metric.
CREATE OR REPLACE VIEW semantic.v_telemetry_latest AS
SELECT *
FROM core.telemetry
QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id, metric ORDER BY window_end DESC) = 1;

-- Impact rationale: resolves each impact-evidence row to a human-readable
-- label and a deep link into the source material.
CREATE OR REPLACE VIEW semantic.v_impact_rationale AS
SELECT ie.subject_kind, ie.subject_id, ie.customer_id,
       ie.evidence_kind, ie.rationale, ie.confidence, ie.created_at,
       CASE ie.evidence_kind
         WHEN 'artifact'   THEN a.title
         WHEN 'ticket'     THEN t.source_key || ' · ' || t.summary
         WHEN 'deployment' THEN ss.name || ' ' || d.version || ' · ' || d.environment
         WHEN 'telemetry'  THEN p.name || ' · ' || tel.metric
       END AS evidence_label,
       CASE ie.evidence_kind
         WHEN 'artifact' THEN a.source_system
         WHEN 'ticket' THEN 'jsm'
         WHEN 'deployment' THEN 'deployinv'
         WHEN 'telemetry' THEN tel.source_system
       END AS evidence_source,
       a.url  AS artifact_url,
       a.kind AS artifact_kind
FROM audit.impact_evidence ie
LEFT JOIN core.artifact a   ON ie.evidence_kind = 'artifact'   AND a.id = ie.evidence_id
LEFT JOIN core.ticket t     ON ie.evidence_kind = 'ticket'     AND t.id = ie.evidence_id
LEFT JOIN core.deployment d ON ie.evidence_kind = 'deployment' AND d.id = ie.evidence_id
LEFT JOIN core.shared_service ss ON ss.id = d.service_id
LEFT JOIN core.telemetry tel ON ie.evidence_kind = 'telemetry' AND tel.id = ie.evidence_id
LEFT JOIN core.product p     ON p.id = tel.product_id;

-- Blast radius: vulnerability × deployment × contractual re-scoring.
CREATE OR REPLACE VIEW semantic.v_blast_radius AS
SELECT v.id AS vulnerability_id, v.ref AS vulnerability_ref, s.name AS service_name,
       cu.id AS customer_id, cu.name AS customer_name, cu.mark,
       d.version, d.environment, COALESCE(d.env_label, d.environment) AS env_label, d.exposure,
       CASE
         WHEN av.version IS NULL THEN 'not_vulnerable'
         WHEN d.environment = 'prod' AND d.exposure = 'internet_facing' THEN 'impacted'
         WHEN d.environment = 'prod' THEN 'impacted'
         ELSE 'potentially_impacted'
       END AS impact,
       sec.clause_ref AS security_clause_ref,
       sec.clause_name AS security_clause_name,
       sec.remedy_type,
       ci.acv_pennies
FROM core.vulnerability v
JOIN core.shared_service s ON s.id = v.service_id
JOIN core.deployment d     ON d.service_id = v.service_id
JOIN core.customer cu      ON cu.id = d.customer_id
LEFT JOIN core.vulnerability_affected_version av
  ON av.vulnerability_id = v.id AND av.version = d.version
LEFT JOIN core.engagement e ON e.customer_id = cu.id AND e.status = 'active'
LEFT JOIN core.contract_instrument ci ON ci.engagement_id = e.id
LEFT JOIN (
  SELECT engagement_id, clause_ref, clause_name, remedy_type
  FROM semantic.v_clause_latest
  WHERE category = 'security_remediation'
) sec ON sec.engagement_id = e.id;
