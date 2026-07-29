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
  -- Client-AGREED tolerance bands, in the metric's own units (not % of target),
  -- captured at contract encoding. 'behind' between target and behind_floor;
  -- 'at_risk' worse than at_risk_floor. Removes the ±10%-of-target nonsense that
  -- let 89.55% pass as merely 'behind' against a 99.5% SLA.
  behind_floor   DOUBLE,                    -- NULL ⇒ fall back to documented default
  at_risk_floor  DOUBLE,
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
  linked_ref    VARCHAR,                    -- work item / ticket / FR it blocks
  -- what the gap holds up here, so ranking honours "severity inherits from the
  -- worst thing blocked" — clause outranks gate outranks incident outranks FR.
  blocks_kind   VARCHAR NOT NULL,           -- clause|gate|incident|feature_request
  clause_id     VARCHAR                     -- the clause at stake, if blocks_kind='clause'
);

-- Milestone gates as first-class, forward-dated records. This is what turns the
-- flagship control from post-mortem ("gate already failed") into pre-mortem
-- ("gate due in 12 days, evidence still missing"). Gate date is projected from
-- Salesforce (the clause spec already names Milestone__c.Gate_Date__c).
CREATE TABLE IF NOT EXISTS core.milestone (
  id                   VARCHAR NOT NULL,
  engagement_id        VARCHAR NOT NULL,
  clause_id            VARCHAR,             -- clause this gate satisfies
  name                 VARCHAR NOT NULL,
  gate_date            DATE NOT NULL,       -- when evidence is due / gate is assessed
  required_requirement VARCHAR,             -- evidence requirement that must be verified
  amount_pennies       BIGINT,             -- milestone payment at stake
  status               VARCHAR NOT NULL     -- upcoming|passed|failed|re_gated
);

-- Client-side people. A departing sponsor / new CFO are top churn precursors and
-- previously had nowhere to live but journal prose.
CREATE TABLE IF NOT EXISTS core.stakeholder (
  id             VARCHAR NOT NULL,
  customer_id    VARCHAR NOT NULL,
  name           VARCHAR NOT NULL,
  role           VARCHAR NOT NULL,
  is_sponsor     BOOLEAN NOT NULL,
  sentiment      VARCHAR,                   -- champion|supportive|neutral|detractor
  status         VARCHAR NOT NULL,          -- active|departing|departed|new
  last_contact_at TIMESTAMP,
  source_system  VARCHAR,                   -- salesforce|manual
  source_ref     VARCHAR
);

-- Definitions of derived measures, served from the lake so the console can
-- explain its own numbers AND so the UI reads its thresholds from ONE place.
-- Every concept the console colours or bands has a row here; the frontend must
-- not hard-code a threshold that lives in `thresholds`.
CREATE TABLE IF NOT EXISTS core.definition (
  key        VARCHAR NOT NULL,              -- 'velocity','health_band','exposure',…
  title      VARCHAR NOT NULL,
  definition VARCHAR NOT NULL,              -- prose a CSM can read to a client
  formula    VARCHAR,                       -- the computable rule
  inputs     VARCHAR,                       -- where the numbers come from
  thresholds JSON                           -- the actual cutoffs the UI consumes
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
  contracted_outcome_id VARCHAR,            -- core.outcome it supports, if any
  clause_id             VARCHAR             -- clause it DEFENDS (e.g. CVE work → §6.3),
                                            -- so clause-defending work counts as aligned,
                                            -- not "operational — supports nothing"
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
  -- HONESTY: how this verdict was produced. The evaluator engine writes
  -- 'evaluated'; fixtures are 'seeded'. The console badges seeded verdicts so
  -- nobody mistakes a fixture for a live control (plan §5 risk: "don't fake
  -- automation"). One clause (§7.2) is evaluated live; the rest are seeded today.
  method       VARCHAR NOT NULL,            -- evaluated|seeded
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
  movement_from VARCHAR NOT NULL,           -- current pair, denormalised for display;
  movement_to   VARCHAR NOT NULL,           -- the audit trail is audit.journal_movement
  state         VARCHAR NOT NULL,           -- open|escalated|closed
  owner         VARCHAR NOT NULL,
  due_note      VARCHAR,
  due_at        TIMESTAMP,                  -- structured deadline → overdue detection + urgency sort
  exposure_pennies BIGINT,                  -- retained for display; portfolio money now derives from v_exposure
  action_label  VARCHAR,                    -- decision-queue button text, if it needs a decision
  action_view   VARCHAR,                    -- console view the action deep-links to
  origin        VARCHAR NOT NULL,           -- control|manual|seed  (who/what raised it, honestly)
  created_at    TIMESTAMP NOT NULL,
  author        VARCHAR NOT NULL
);

-- Append-only movement log: the journal's real audit spine. State changes append
-- a row here instead of mutating journal_entry, so the "immutable log" branding
-- is mechanically true. journal_entry.state/movement_* are the denormalised head.
CREATE TABLE IF NOT EXISTS audit.journal_movement (
  id          VARCHAR NOT NULL,
  journal_id  VARCHAR NOT NULL,
  seq         BIGINT NOT NULL,             -- 1,2,3… per journal_id
  from_state  VARCHAR,
  to_state    VARCHAR NOT NULL,
  note        VARCHAR,
  actor       VARCHAR NOT NULL,
  moved_at    TIMESTAMP NOT NULL
);

-- Decision records: closes the raised→DECIDED→acted→verified loop. A decision-
-- queue item is resolved by writing a decision here (who, when, which option,
-- rationale, verify-by), not by silently closing the whole risk.
CREATE TABLE IF NOT EXISTS audit.decision (
  id          VARCHAR NOT NULL,
  journal_id  VARCHAR NOT NULL,            -- the risk this decides
  option      VARCHAR NOT NULL,            -- what was decided
  rationale   VARCHAR,
  decided_by  VARCHAR NOT NULL,
  decided_at  TIMESTAMP NOT NULL,
  verify_by   DATE,                        -- when we confirm it worked
  status      VARCHAR NOT NULL             -- decided|verified|reopened
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

-- Outcome status: latest measurement vs target, banded by CLIENT-AGREED
-- tolerances (core.outcome.behind_floor / at_risk_floor), not ±10% of target.
-- 'behind' = below target but at/above behind_floor; 'at_risk' = below that.
-- Fallback floors (documented in core.definition 'outcome_status') apply only
-- where a client tolerance wasn't captured. window_* carried through so the QBR
-- linter can compare measurement window to the reporting period.
CREATE OR REPLACE VIEW semantic.v_outcome_status AS
SELECT r.id AS outcome_id, r.engagement_id, r.name, r.target_display, r.measure_source,
       m.display_value AS actual_display, m.value AS actual_value, r.target_value, r.direction,
       m.source_ref,
       m.window_start, m.window_end, r.window_kind, r.window_days,
       CASE
         WHEN m.value IS NULL THEN 'unknown'
         WHEN (r.direction = 'gte' AND m.value >= r.target_value)
           OR (r.direction = 'lte' AND m.value <= r.target_value) THEN 'met'
         WHEN (r.direction = 'gte' AND m.value >= r.bf)
           OR (r.direction = 'lte' AND m.value <= r.bf) THEN 'behind'
         ELSE 'at_risk'
       END AS status,
       -- true when even the at_risk_floor is breached (escalation flag)
       CASE WHEN m.value IS NOT NULL AND
                 ((r.direction = 'gte' AND m.value < r.arf) OR
                  (r.direction = 'lte' AND m.value > r.arf)) THEN TRUE ELSE FALSE END AS is_critical,
       CASE
         WHEN m.value IS NULL THEN 0.0
         WHEN r.direction = 'gte' THEN LEAST(100.0, 100.0 * m.value / r.target_value)
         ELSE LEAST(100.0, 100.0 * r.target_value / NULLIF(m.value, 0))
       END AS attainment_pct
FROM (
  SELECT o.*,
    COALESCE(o.behind_floor, CASE WHEN o.direction = 'gte'
      THEN o.target_value - GREATEST(o.target_value * 0.01, 1.0)
      ELSE o.target_value + GREATEST(o.target_value * 0.01, 1.0) END) AS bf,
    COALESCE(o.at_risk_floor, CASE WHEN o.direction = 'gte'
      THEN o.target_value - GREATEST(o.target_value * 0.03, 2.0)
      ELSE o.target_value + GREATEST(o.target_value * 0.03, 2.0) END) AS arf
  FROM core.outcome o
) r
LEFT JOIN semantic.v_measure_latest m
  ON m.engagement_id = r.engagement_id AND m.metric = r.measure_metric;

-- Utilisation streak: consecutive most-recent weeks over 100%. Makes the
-- "sustained over-utilisation for N weeks" control real instead of prose.
CREATE OR REPLACE VIEW semantic.v_util_streak AS
WITH w AS (
  SELECT engagement_id, value,
         ROW_NUMBER() OVER (PARTITION BY engagement_id ORDER BY window_end DESC) AS rn
  FROM core.measurement WHERE metric = 'utilisation_pct'
)
SELECT engagement_id,
       COALESCE(MIN(CASE WHEN value <= 100 THEN rn END) - 1, MAX(rn)) AS weeks_over_100
FROM w GROUP BY engagement_id;

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

-- Per-engagement rollup feeding the health band. cannot_evaluate is counted
-- (stale evidence must NOT silently improve the band); at-risk outcomes and the
-- over-util streak are surfaced so the band can be honest and fail-visible.
CREATE OR REPLACE VIEW semantic.v_engagement_rollup AS
SELECT e.id AS engagement_id, e.customer_id,
       COALESCE(cl.breaches, 0)       AS clause_breaches,
       COALESCE(cl.at_risk, 0)        AS clauses_at_risk,
       COALESCE(cl.cannot_eval, 0)    AS clauses_cannot_eval,
       COALESCE(cl.total, 0)          AS clauses_total,
       COALESCE(oc.on_track, 0)       AS outcomes_on_track,
       COALESCE(oc.at_risk, 0)        AS outcomes_at_risk,
       COALESCE(oc.total, 0)          AS outcomes_total,
       um.value                       AS utilisation_pct,
       mm.value                       AS margin_pct,
       COALESCE(us.weeks_over_100, 0) AS util_weeks_over_100,
       vt.delta_pct                   AS velocity_delta_pct
FROM core.engagement e
LEFT JOIN (
  SELECT engagement_id,
         SUM(CASE WHEN verdict = 'breach'          THEN 1 ELSE 0 END) AS breaches,
         SUM(CASE WHEN verdict = 'at_risk'         THEN 1 ELSE 0 END) AS at_risk,
         SUM(CASE WHEN verdict = 'cannot_evaluate' THEN 1 ELSE 0 END) AS cannot_eval,
         COUNT(*) AS total
  FROM semantic.v_clause_latest GROUP BY engagement_id
) cl ON cl.engagement_id = e.id
LEFT JOIN (
  SELECT engagement_id,
         SUM(CASE WHEN status = 'met' THEN 1 ELSE 0 END)     AS on_track,
         SUM(CASE WHEN status = 'at_risk' THEN 1 ELSE 0 END) AS at_risk,
         COUNT(*) AS total
  FROM semantic.v_outcome_status GROUP BY engagement_id
) oc ON oc.engagement_id = e.id
LEFT JOIN semantic.v_measure_latest um
  ON um.engagement_id = e.id AND um.metric = 'utilisation_pct'
LEFT JOIN semantic.v_measure_latest mm
  ON mm.engagement_id = e.id AND mm.metric = 'margin_pct'
LEFT JOIN semantic.v_util_streak us ON us.engagement_id = e.id
LEFT JOIN semantic.v_velocity_trend vt ON vt.engagement_id = e.id
WHERE e.status = 'active';

-- One contract position per engagement — instruments AGGREGATED, so a client
-- with "MSA + 3 SOWs" is one row with summed ACV, not four rows double-counting
-- the account in every KPI. renewal = earliest across instruments.
CREATE OR REPLACE VIEW semantic.v_engagement_contract AS
SELECT engagement_id,
       SUM(acv_pennies) AS acv_pennies,
       SUM(tcv_pennies) AS tcv_pennies,
       MIN(renewal_date) AS renewal_date,
       MIN(notice_days)  AS notice_days,
       STRING_AGG(DISTINCT vehicle_label, ' · ') AS vehicle_label,
       MAX(delta_label)  AS delta_label,
       COUNT(*)          AS instrument_count
FROM core.contract_instrument
GROUP BY engagement_id;

-- Health band, definition v2 (rule-based, defensible, FAIL-VISIBLE — the full
-- prose + thresholds live in core.definition 'health_band' so the console reads
-- one source). Key fixes over v1:
--   * missing utilisation is NOT coerced to 100 (no "healthy by default"); it
--     surfaces as data_quality, never as a passing signal.
--   * cannot_evaluate clauses and at-risk outcomes count toward the band, so
--     stale evidence cannot improve it.
--   * sustained over-util (streak ≥ 4 wks) and a renewal inside its notice
--     window with no open motion are first-class escalators.
--   at_risk : ≥2 breaches; or a breach with <50% outcomes on track; or a renewal
--             inside notice window with no open opportunity.
--   watch   : any breach / at-risk clause / cannot-evaluate / at-risk outcome;
--             util >100 or <75; ≥4-week over-util streak; steep velocity drop
--             alongside an at-risk outcome.
--   on_track: otherwise.
CREATE OR REPLACE VIEW semantic.v_customer_signal AS
SELECT cu.id AS customer_id, cu.name, cu.mark, cu.sector, cu.csm_name,
       r.engagement_id,
       CASE
         WHEN r.clause_breaches >= 2
           OR (r.clause_breaches >= 1 AND r.outcomes_on_track * 2 < r.outcomes_total)
           OR (ct.renewal_date IS NOT NULL
               AND DATE_DIFF('day', CURRENT_DATE, ct.renewal_date) <= COALESCE(ct.notice_days, 60)
               AND COALESCE(rm.opportunity_open, TRUE) = FALSE)          THEN 'at_risk'
         WHEN r.clause_breaches >= 1 OR r.clauses_at_risk >= 1 OR r.clauses_cannot_eval >= 1
           OR r.outcomes_at_risk >= 1
           OR (r.utilisation_pct IS NOT NULL AND (r.utilisation_pct > 100 OR r.utilisation_pct < 75))
           OR r.util_weeks_over_100 >= 4
           OR (r.velocity_delta_pct <= -15 AND r.outcomes_at_risk >= 1) THEN 'watch'
         ELSE 'on_track'
       END AS health_band,
       r.outcomes_on_track, r.outcomes_at_risk, r.outcomes_total,
       r.clause_breaches, r.clauses_at_risk, r.clauses_cannot_eval, r.clauses_total,
       r.utilisation_pct, r.margin_pct, r.util_weeks_over_100, r.velocity_delta_pct,
       -- data quality: what's missing, so a blank never reads as healthy
       (CASE WHEN r.utilisation_pct IS NULL THEN 1 ELSE 0 END
        + CASE WHEN r.margin_pct IS NULL THEN 1 ELSE 0 END) AS missing_signals,
       ct.vehicle_label, COALESCE(ct.acv_pennies, 0) AS acv_pennies,
       ct.renewal_date, ct.notice_days, ct.delta_label, ct.instrument_count,
       DATE_DIFF('day', CURRENT_DATE, ct.renewal_date) AS renewal_days,
       COALESCE(rm.opportunity_open, TRUE) AS opportunity_open,
       COALESCE(j.open_risks, 0) AS open_risks,
       COALESCE(j.crit_risks, 0) AS crit_risks
FROM core.customer cu
JOIN semantic.v_engagement_rollup r ON r.customer_id = cu.id
LEFT JOIN semantic.v_engagement_contract ct ON ct.engagement_id = r.engagement_id
LEFT JOIN core.renewal_motion rm ON rm.engagement_id = r.engagement_id
LEFT JOIN (
  SELECT jc.customer_id,
         COUNT(*) AS open_risks,
         SUM(CASE WHEN je.tone = 'crit' THEN 1 ELSE 0 END) AS crit_risks
  FROM audit.journal_entry je
  JOIN audit.journal_entry_customer jc ON jc.journal_id = je.id
  WHERE je.state <> 'closed'
  GROUP BY jc.customer_id
) j ON j.customer_id = cu.id;

-- ONE exposure definition (replaces three conflicting ones). Per customer,
-- one row → no double counting:
--   * remedy_pennies    — money contractually crystallised NOW (sum of live
--     breach/at-risk clause remedies), excluding uncapped which can't be summed.
--   * has_uncapped      — flagged separately, never invented as a number.
--   * acv_under_watch   — the account's ACV, counted once, only when not on_track;
--     labelled "under watch", not "at risk" (context, not a loss estimate).
-- Grain is ONE ROW PER CUSTOMER (aggregated from the per-engagement signal), so
-- SUM() in the KPI can never double-count a multi-engagement customer — the
-- exact identity-spine trap. band = worst across the customer's engagements.
CREATE OR REPLACE VIEW semantic.v_exposure AS
SELECT pc.customer_id, cu.name, cu.mark,
       CASE pc.band_rank WHEN 2 THEN 'at_risk' WHEN 1 THEN 'watch' ELSE 'on_track' END AS health_band,
       pc.acv_pennies,
       COALESCE(bc.remedy_pennies, 0) AS remedy_pennies,
       CASE WHEN COALESCE(bc.has_uncapped, 0) = 1 THEN TRUE ELSE FALSE END AS has_uncapped,
       CASE WHEN pc.band_rank > 0 THEN pc.acv_pennies ELSE 0 END AS acv_under_watch_pennies,
       COALESCE(bc.live_clause_count, 0) AS live_clause_count
FROM (
  SELECT customer_id,
         MAX(CASE health_band WHEN 'at_risk' THEN 2 WHEN 'watch' THEN 1 ELSE 0 END) AS band_rank,
         SUM(acv_pennies) AS acv_pennies
  FROM semantic.v_customer_signal GROUP BY customer_id
) pc
JOIN core.customer cu ON cu.id = pc.customer_id
LEFT JOIN (
  SELECT e.customer_id,
    SUM(CASE WHEN cl.remedy_amount_pennies IS NOT NULL AND COALESCE(cl.remedy_type,'') <> 'uncapped_credit'
             THEN cl.remedy_amount_pennies ELSE 0 END) AS remedy_pennies,
    MAX(CASE WHEN cl.remedy_type = 'uncapped_credit' THEN 1 ELSE 0 END) AS has_uncapped,
    COUNT(*) AS live_clause_count
  FROM semantic.v_clause_latest cl
  JOIN core.engagement e ON e.id = cl.engagement_id
  WHERE cl.verdict IN ('breach', 'at_risk')
  GROUP BY e.customer_id
) bc ON bc.customer_id = pc.customer_id;

-- Outcome coverage: does capacity actually stand behind each contracted outcome?
-- Flags an unmet/at-risk/unknown outcome with ZERO committed FTE — the exact
-- silent misalignment the platform exists to prevent, now a queryable list.
CREATE OR REPLACE VIEW semantic.v_outcome_coverage AS
SELECT o.engagement_id, os.outcome_id, o.name AS outcome_name,
       os.status AS outcome_status, os.attainment_pct,
       COUNT(DISTINCT d.id) AS delivery_outcomes,
       COALESCE(SUM(a.assigned_fte), 0) AS committed_fte,
       CASE WHEN os.status IN ('at_risk', 'behind', 'unknown')
             AND COALESCE(SUM(a.assigned_fte), 0) = 0 THEN TRUE ELSE FALSE END AS unaligned
FROM core.outcome o
JOIN semantic.v_outcome_status os ON os.outcome_id = o.id
LEFT JOIN core.delivery_outcome d ON d.contracted_outcome_id = o.id
LEFT JOIN core.assignment a ON a.delivery_outcome_id = d.id
GROUP BY o.engagement_id, os.outcome_id, o.name, os.status, os.attainment_pct;

-- Gate runway: forward-looking. Milestones with days-to-gate and whether the
-- required evidence is verified yet — so a gate trending to fail is visible
-- BEFORE the window closes, not after.
CREATE OR REPLACE VIEW semantic.v_gate_runway AS
SELECT ms.id, ms.engagement_id, e.customer_id, cu.name AS customer_name, cu.mark,
       ms.name, ms.gate_date, ms.amount_pennies, ms.status,
       ms.clause_id, c.ref AS clause_ref,
       DATE_DIFF('day', CURRENT_DATE, ms.gate_date) AS days_to_gate,
       ev.state AS evidence_state,
       CASE WHEN ev.state = 'verified' THEN TRUE ELSE FALSE END AS evidence_ready
FROM core.milestone ms
JOIN core.engagement e ON e.id = ms.engagement_id
JOIN core.customer cu ON cu.id = e.customer_id
LEFT JOIN core.clause c ON c.id = ms.clause_id
LEFT JOIN core.evidence ev
  ON ev.engagement_id = ms.engagement_id AND ev.requirement = ms.required_requirement
QUALIFY ROW_NUMBER() OVER (PARTITION BY ms.id ORDER BY
  CASE ev.state WHEN 'verified' THEN 0 WHEN 'attached' THEN 1 WHEN 'stale' THEN 2 ELSE 3 END) = 1;

-- Platform gaps ranked by the WORST thing each blocks, then reach — honouring
-- the served definition (clause > gate > incident > feature request).
CREATE OR REPLACE VIEW semantic.v_platform_gap_ranked AS
SELECT g.id, g.name, g.description, g.status, g.eta, g.owner,
       COUNT(DISTINCT gc.customer_id) AS reach,
       MIN(CASE gc.blocks_kind WHEN 'clause' THEN 0 WHEN 'gate' THEN 1
                               WHEN 'incident' THEN 2 ELSE 3 END) AS worst_kind_rank,
       CASE MIN(CASE gc.blocks_kind WHEN 'clause' THEN 0 WHEN 'gate' THEN 1
                                    WHEN 'incident' THEN 2 ELSE 3 END)
         WHEN 0 THEN 'clause' WHEN 1 THEN 'gate' WHEN 2 THEN 'incident'
         ELSE 'feature_request' END AS worst_blocks_kind
FROM core.platform_gap g
JOIN core.platform_gap_customer gc ON gc.gap_id = g.id
GROUP BY g.id, g.name, g.description, g.status, g.eta, g.owner;

-- Client voice / leading indicators — the signals that measure the CLIENT'S
-- experience, not our delivery: CSAT trend, engagement silence, waiting-on-client
-- dwell, sponsor status. These are what would have caught Solent a quarter early.
CREATE OR REPLACE VIEW semantic.v_client_voice AS
SELECT cu.id AS customer_id, cu.name,
       ca.csat_latest, ca.csat_prev, ROUND(ca.csat_latest - ca.csat_prev, 1) AS csat_delta,
       DATE_DIFF('day', act.last_client_activity, CURRENT_TIMESTAMP) AS days_since_client_activity,
       act.waiting_client_days, act.open_tickets,
       sp.sponsor_status, sp.sponsor_sentiment
FROM core.customer cu
LEFT JOIN (
  SELECT customer_id,
         MAX(CASE WHEN rn = 1 THEN value END) AS csat_latest,
         MAX(CASE WHEN rn = 2 THEN value END) AS csat_prev
  FROM (
    SELECT e.customer_id, m.value,
           ROW_NUMBER() OVER (PARTITION BY e.customer_id ORDER BY m.window_end DESC) AS rn
    FROM core.measurement m JOIN core.engagement e ON e.id = m.engagement_id
    WHERE m.metric = 'csat'
  ) q GROUP BY customer_id
) ca ON ca.customer_id = cu.id
LEFT JOIN (
  SELECT customer_id,
         MAX(last_activity_at) AS last_client_activity,
         MAX(CASE WHEN status = 'waiting_client'
                  THEN DATE_DIFF('day', last_activity_at, CURRENT_TIMESTAMP) END) AS waiting_client_days,
         SUM(CASE WHEN status <> 'resolved' THEN 1 ELSE 0 END) AS open_tickets
  FROM core.ticket GROUP BY customer_id
) act ON act.customer_id = cu.id
LEFT JOIN (
  -- one sponsor row per customer — the most concerning (worst status, then worst
  -- sentiment, then most recent), so status and sentiment come from the SAME
  -- person rather than independent column MAXes.
  SELECT customer_id, status AS sponsor_status, sentiment AS sponsor_sentiment
  FROM core.stakeholder WHERE is_sponsor
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY
    CASE status WHEN 'departed' THEN 0 WHEN 'departing' THEN 1 WHEN 'new' THEN 2 ELSE 3 END,
    CASE sentiment WHEN 'detractor' THEN 0 WHEN 'neutral' THEN 1 WHEN 'supportive' THEN 2 ELSE 3 END,
    last_contact_at DESC) = 1
) sp ON sp.customer_id = cu.id;

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
-- JSM tickets: age = days since last activity, so waiting_client stalls (a
-- disengagement proxy) are visible, not just Jira "blocked".
SELECT t.customer_id, t.source_key, 'jsm', COALESCE(t.request_type, 'request'), t.summary,
       t.status, NULL,
       CASE WHEN t.status IN ('waiting_client', 'waiting_us', 'open')
            THEN DATE_DIFF('day', CAST(t.last_activity_at AS DATE), CURRENT_DATE) END,
       NULL, t.priority
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
       cs.utilisation_pct, cs.open_risks, cs.acv_pennies, cs.renewal_days,
       cs.csm_name,
       -- staleness: how old the baseline is. The console reads the suppression
       -- threshold from core.definition 'rag_snapshot' and GREYS/holds the deltas
       -- (not just a banner) once the baseline exceeds it, so a dead snapshot job
       -- cannot present old diffs as "this week".
       DATE_DIFF('day', ss.snapshot_date, CURRENT_DATE) AS snapshot_age_days
FROM semantic.v_customer_signal cs
LEFT JOIN (
  -- Baseline = the most recent checkpoint at least ~a week old, so a snapshot the
  -- writer wrote yesterday can't become the baseline and collapse the diff to one
  -- day. This is the weekly "what changed since we last talked" conversation line.
  SELECT * FROM audit.signal_snapshot
  WHERE snapshot_date <= CURRENT_DATE - 6
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
       COALESCE(sh.customers_sharing, 1) AS customers_sharing,
       CAST(LEAST(t.comment_count, 20) * 1.0        -- capped: a long healthy thread ≠ severe
          + t.reopen_count * 6.0                    -- reopens are the strongest churn-toward-severe signal
          + t.participant_count * 2.0
          + CASE WHEN COALESCE(sh.customers_sharing, 1) > 1 THEN 10.0 ELSE 0.0 END
          + CASE t.priority WHEN 'high' THEN 8.0 WHEN 'medium' THEN 3.0 ELSE 0.0 END
          - CASE WHEN t.status = 'waiting_client' THEN 6.0 ELSE 0.0 END  -- the ball is in the client's court
         AS DOUBLE) AS bubble_score
FROM core.ticket t
JOIN core.customer cu ON cu.id = t.customer_id
-- LEFT JOIN so NULL-fingerprint tickets (all of them until a fingerprinting
-- engine exists) still appear rather than the panel silently emptying.
LEFT JOIN (
  SELECT fingerprint, COUNT(DISTINCT customer_id) AS customers_sharing
  FROM core.ticket WHERE fingerprint IS NOT NULL GROUP BY fingerprint
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
LEFT JOIN semantic.v_engagement_contract ci ON ci.engagement_id = e.id
LEFT JOIN (
  SELECT engagement_id, clause_ref, clause_name, remedy_type
  FROM semantic.v_clause_latest
  WHERE category = 'security_remediation'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY engagement_id ORDER BY clause_ref) = 1
) sec ON sec.engagement_id = e.id;
