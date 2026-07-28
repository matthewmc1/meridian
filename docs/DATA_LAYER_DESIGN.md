# Meridian — Data Layer Design & Build Walkthrough
## v1 · 28 Jul 2026 · companion to PROJECT_PLAN.md

This is the build-facing design for the foundational layer: how each source system is integrated,
how raw records become canonical entities, and the concrete order in which we build it. Terminology:
the collective is **customers** (never "fleet"); the individual record is a **customer** with one or
more **engagements**.

---

## 0 · Architecture at a glance

```
┌─ SOURCES ─────────────┐  ┌─ INGESTION ─────────┐  ┌─ STORAGE (Postgres) ────────────────┐  ┌─ SERVING ──────────┐
│ Salesforce            │  │ connector framework  │  │ staging.*    raw, immutable, JSONB  │  │ REST/GraphQL API   │
│ Workday               │  │ - scheduled pulls    │  │ core.*       canonical entities     │  │ - console (5 views)│
│ Jira Software         │──▶ - webhooks (Jira/JSM/│──▶ semantic.*   derived views + snaps  │──▶ - QBR generator    │
│ Jira Service Mgmt     │  │   Confluence/Drive)  │  │ audit.*      journal, evaluations,  │  │ - notifications    │
│ Confluence            │  │ - watermark cursors  │  │              lineage                │  │ - export (PDF)     │
│ Google Drive          │  │ - idempotent upserts │  └─────────────────────────────────────┘  └────────────────────┘
│ Deploy inventory/CMDB │  └──────────────────────┘         ▲
└───────────────────────┘        engines: clause evaluator · control scheduler · correlation graph · claim linter
```

Stack recommendation (pragmatic, small team):

- **Postgres 16** as the single store — staging (JSONB), canonical (relational), semantic
  (views/materialized views). No warehouse until scale demands it; 8–15 accounts per CSM is tiny data.
- **Go services**: one `connector` binary with per-source adapters, one `engine` service (clause
  evaluation, controls, correlation), one `api` service. Shared module for provenance, crosswalk,
  retries.
- **Orchestration**: simple in-process scheduler (cron-style) per connector + webhook receivers.
  No Airflow/Temporal in v1 — revisit if backfills get painful.
- **Queue**: Postgres `LISTEN/NOTIFY` + an `ingest_events` table as the change feed between
  ingestion and engines. Avoid Kafka until it's earned.

---

## 1 · Integration design, source by source

Common contract every connector implements:

```go
type Connector interface {
    // Backfill pulls everything for the configured scope (initial load / repair).
    Backfill(ctx context.Context, scope Scope) error
    // Sync pulls changes since the stored watermark (cursor, updated-at, or change token).
    Sync(ctx context.Context) error
    // HandleWebhook applies a pushed event, then enqueues a reconcile of that record.
    HandleWebhook(ctx context.Context, payload []byte) error
}
```

Rules that apply to all seven:

1. **Read-only.** Dedicated integration user per source with least-privilege, read-only scopes.
2. **Webhook fast path, poll for truth.** Webhooks give freshness; a reconciling incremental poll
   (watermark on `updated_at`/cursor) guarantees nothing is missed. Webhooks are treated as hints —
   on receipt we re-fetch the record from the API, never trust the payload as state.
3. **Idempotent upserts** keyed on `(source_system, source_record_id)`; every landed record gets
   `extracted_at`, `payload_hash`. Unchanged hash ⇒ no new staging row.
4. **Rate-limit aware**: token budget per source, exponential backoff, and a per-source
   `sync_status` row (last success, last error, lag) that feeds the sidebar freshness dots.

### 1.1 Salesforce — commercial truth
- **API**: REST + Bulk API 2.0 for backfill; **Pub/Sub API (Change Data Capture)** for near-real-time
  on Account, Contract, Opportunity.
- **Auth**: OAuth 2.0 JWT bearer flow, integration user with a read-only permission set scoped to
  the objects below.
- **Objects → canonical**: `Account` → customer · `Contract` + custom contract-instrument object →
  contract_instrument · `Opportunity` (renewal/expansion) → renewal_motion · change-order custom
  object → change_order · CSAT survey object → measurement(csat).
- **Cadence**: CDC stream + 15-min reconcile poll + nightly full-diff on the small object set.
- **Gotchas**: clause *text* may live in attached CLM docs, not fields — clause specs are authored
  in Meridian and *reference* the Salesforce contract record (see §3.2).

### 1.2 Workday — people, capacity, money
- **API**: **RaaS (Report-as-a-Service)** — custom reports exposed as REST/JSON endpoints. This is
  deliberate: raw Workday SOAP objects are painful; RaaS lets Workday admins own the shape.
  Reports needed: assignments by project, utilisation by worker-week, open requisitions,
  attrition/turnover flags, project financials (burn, margin).
- **Auth**: ISU (Integration System User) + OAuth client credentials, report-scoped.
- **Cadence**: scheduled pull every 2 h (Workday data is batch-natured; don't pretend otherwise).
  Nightly backfill of the trailing 8 weeks to catch retroactive timesheet edits — **utilisation
  restates**, and the canonical layer versions those restatements rather than overwriting.
- **Gotchas**: worker↔project mapping needs the crosswalk (Workday project id ↔ engagement).

### 1.3 Jira Software — delivery evidence
- **API**: REST v3 + Agile API (boards, sprints, velocity); attachments metadata for evidence.
- **Auth**: OAuth 2.0 (3LO) app or scoped API token on a service account; read scopes only
  (`read:jira-work`).
- **Events**: webhooks on issue created/updated/transitioned, attachment added, sprint closed —
  attachment-added is the trigger for gate-evidence re-evaluation, which is what makes "evidence
  missing → attached" reflect within minutes.
- **Objects → canonical**: epic/issue → work_item · sprint + points → velocity measurements ·
  attachment → evidence artifact_ref (kind `jira_attachment`) · issue links → work↔outcome/clause
  mapping (via labels or a custom field `meridian-outcome`, agreed with delivery teams).
- **Gotchas**: blocked-age isn't native — derive from status-transition history (changelog API),
  computed in the semantic layer.

### 1.4 Jira Service Management — service operations (internal service desk)
JSM shares the Jira platform (same auth app, same webhook infrastructure) but has its own APIs.
- **API**: Service Desk REST API — requests, request types, queues, organizations; **SLA API**
  (`/rest/servicedeskapi/request/{id}/sla`) for cycle data: time-to-first-response,
  time-to-resolution, breached/paused/ongoing per SLA.
- **Objects → canonical**: request/incident → ticket · SLA cycles → measurement(sla_*) — these are
  the *evidence records* for availability/response clauses · JSM `organization` → customer (via
  crosswalk) · request type + components → symptom taxonomy inputs.
- **Why it matters for correlation**: JSM tickets are the raw feed for the symptom graph. We ingest
  summary, description, components, linked issues, and request-type — the clustering engine
  fingerprints these (§4), so two customers describing the same defect differently still cluster.
- **Cadence**: webhooks + 15-min reconcile.

### 1.5 Confluence — long-form documents as linkable evidence
Confluence is where runbooks, decision records, UAT reports, and architecture docs live. We do
**not** copy content wholesale; we index and link.
- **API**: Confluence REST v2 — spaces, pages, page **versions**, labels, content properties;
  webhooks on page created/updated.
- **What we ingest**: page metadata (space, title, version, labels, last-modified, author), the
  link graph (which pages reference which Jira issues / which pages other pages), and extracted
  text *only* for pages labelled as evidence (`meridian-evidence`, `runbook`, `decision-record`) to
  support search.
- **Evidence semantics**: an evidence record referencing a Confluence page **pins the page version**
  at verification time. If the page is edited afterwards, the evidence flips to `stale` and the
  owning control re-fires — a QBR can never cite a document that changed after sign-off without
  the change being visible.
- **Convention to establish with delivery teams**: one space per engagement (crosswalk maps space
  key → engagement); evidence pages carry the label taxonomy above.

### 1.6 Google Drive — signed client artifacts
Drive holds the client-facing signed things: executed contracts and change orders, benefit-case
sign-offs, exported QBR packs.
- **API**: Drive API v3. Per-customer **shared drive** (one per engagement, crosswalk-mapped).
  Incremental sync via `changes.list` with a stored page token per shared drive; `files.watch`
  push channels for freshness (they expire ≤ 24 h — the reconcile poll is the safety net, as
  everywhere).
- **Auth**: service account with domain-wide delegation *or* per-drive sharing to the service
  account — decide with IT security; scope `drive.readonly`.
- **What we ingest**: file metadata (name, mime, **headRevisionId**, modifiedTime, path), sharing/
  permission summary (who outside the org can see it — feeds a data-exposure control), and a
  content hash. Content itself stays in Drive; Meridian deep-links.
- **Evidence semantics**: same pinning model as Confluence — evidence records pin `revisionId`.
  "Signed CO" verification = correct folder + naming convention + revision pinned + (later phase)
  countersignature detection.
- **Gotchas**: naming/folder conventions are a human control; the missing-artifact checker
  validates the convention (`/<engagement>/contracts/`, `/<engagement>/sign-offs/`…) and flags
  deviations rather than guessing.

### 1.7 Deployment inventory (correlation backbone)
- **v1**: a governed `deployments.yaml` per engagement in a Git repo (component, version,
  environment, exposure), synced on merge — accurate enough to ship correlation in Phase 4.
- **v2**: automate from CI/CD pipelines or CMDB export; the YAML becomes the override/annotation
  layer.

---

## 2 · Storage design

### 2.1 `staging.*` — raw and immutable

One pattern for every source:

```sql
CREATE TABLE staging.source_record (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_system  text NOT NULL,          -- 'salesforce' | 'workday' | 'jira' | 'jsm' | 'confluence' | 'gdrive' | 'deployinv'
  source_type    text NOT NULL,          -- e.g. 'Account', 'issue', 'page', 'file', 'sla_cycle'
  source_id      text NOT NULL,          -- native id in the source
  payload        jsonb NOT NULL,         -- verbatim API response
  payload_hash   text NOT NULL,
  extracted_at   timestamptz NOT NULL,
  batch_id       uuid NOT NULL
);
-- append-only: new row per observed change; latest = max(extracted_at) per (source_system, source_type, source_id)
CREATE INDEX ON staging.source_record (source_system, source_type, source_id, extracted_at DESC);
```

Staging is the replay log: canonical can be rebuilt from it at any time, and "what did we know at
QBR generation time" is answerable by timestamp.

### 2.2 `core.*` — canonical entities (key DDL sketches)

```sql
-- Identity spine
CREATE TABLE core.customer (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  sector       text,
  csm_user_id  uuid REFERENCES core.app_user(id)
);

CREATE TABLE core.engagement (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   uuid NOT NULL REFERENCES core.customer(id),
  name          text NOT NULL,
  delivery_lead text,
  status        text NOT NULL DEFAULT 'active'
);

-- THE crosswalk: every native id that means "this engagement/customer"
CREATE TABLE core.crosswalk (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_kind    text NOT NULL,      -- 'customer' | 'engagement'
  entity_id      uuid NOT NULL,
  source_system  text NOT NULL,
  source_type    text NOT NULL,      -- 'sf_account', 'jira_project', 'jsm_org', 'confluence_space', 'gdrive_drive', 'wd_project'
  source_id      text NOT NULL,
  confidence     text NOT NULL DEFAULT 'manual',   -- 'manual' | 'high' | 'review'
  UNIQUE (source_system, source_type, source_id)
);
-- Ingested records that match no crosswalk row land in core.unmapped_record (the data-quality queue).

-- Contract layer
CREATE TABLE core.contract_instrument (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engagement_id  uuid NOT NULL REFERENCES core.engagement(id),
  ref            text NOT NULL,            -- 'MSA-2023-041', 'SOW-14'
  kind           text NOT NULL,            -- msa | sow | call_off | framework | retainer
  commercial     jsonb NOT NULL,           -- acv, tcv, currency, renewal_date, notice_days…
  source_ref     jsonb NOT NULL            -- provenance: salesforce record id(s)
);

CREATE TABLE core.clause (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_id   uuid NOT NULL REFERENCES core.contract_instrument(id),
  ref             text NOT NULL,           -- '§7.2'
  name            text NOT NULL,
  spec            jsonb NOT NULL,          -- machine-checkable test (see §3.2), versioned
  spec_version    int  NOT NULL DEFAULT 1,
  remedy          jsonb,                   -- {type:'milestone_hold', amount_pennies:34000000} | {type:'sla_credit',…} | {type:'uncapped_credit'}
  check_cadence   interval NOT NULL DEFAULT '15 minutes',
  tier            text NOT NULL            -- 'auto' | 'assisted' | 'manual_attest'
);

-- Outcomes & measurements
CREATE TABLE core.outcome (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engagement_id  uuid NOT NULL REFERENCES core.engagement(id),
  name           text NOT NULL,
  target         jsonb NOT NULL,           -- {value: 99.5, unit:'%', direction:'gte'}
  window         jsonb NOT NULL,           -- {kind:'rolling', days:30} | {kind:'period', …}  ← claim linter compares this to reporting period
  measure_source text NOT NULL             -- which measurement feed proves it
);

CREATE TABLE core.measurement (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  outcome_id   uuid REFERENCES core.outcome(id),
  metric       text NOT NULL,              -- 'crash_free_rate', 'sla_ttr_p50', 'utilisation', 'csat'
  scope        jsonb NOT NULL,             -- engagement/team/component the number is about
  value        numeric NOT NULL,
  window_start timestamptz NOT NULL,
  window_end   timestamptz NOT NULL,
  source_ref   jsonb NOT NULL              -- staging row(s) this was computed from
);

-- Work & evidence
CREATE TABLE core.work_item (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engagement_id uuid NOT NULL REFERENCES core.engagement(id),
  source_key    text NOT NULL,             -- 'NWR-482'
  kind          text NOT NULL,             -- epic | story | ticket(jsm)
  title         text NOT NULL,
  state         text NOT NULL,
  blocked_since timestamptz,
  links         jsonb NOT NULL DEFAULT '{}'::jsonb   -- outcome_ids, clause_ids
);

CREATE TABLE core.artifact_ref (            -- polymorphic pointer into Jira/Confluence/Drive
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind          text NOT NULL,             -- 'jira_attachment' | 'confluence_page' | 'gdrive_file'
  source_id     text NOT NULL,
  pinned_version text,                     -- confluence version / drive headRevisionId (NULL until verified)
  url           text NOT NULL,
  content_hash  text
);

CREATE TABLE core.evidence (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engagement_id uuid NOT NULL REFERENCES core.engagement(id),
  requirement   text NOT NULL,             -- 'uat_pack', 'release_note', 'signed_benefit_case', 'runbook', 'signed_co'
  artifact_id   uuid REFERENCES core.artifact_ref(id),   -- NULL ⇒ MISSING (first-class negative record)
  state         text NOT NULL,             -- missing | attached | verified | stale
  due_at        timestamptz,               -- window the artifact must exist by
  verified_by   uuid, verified_at timestamptz
);

-- Correlation backbone
CREATE TABLE core.shared_service (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, current_version text
);
CREATE TABLE core.deployment (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id    uuid NOT NULL REFERENCES core.shared_service(id),
  customer_id   uuid NOT NULL REFERENCES core.customer(id),
  version       text NOT NULL,
  environment   text NOT NULL,             -- prod | staging
  exposure      text NOT NULL,             -- internet_facing | internal | none
  UNIQUE (service_id, customer_id, environment)
);

CREATE TABLE core.ticket (                  -- JSM feed for the symptom graph
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   uuid NOT NULL REFERENCES core.customer(id),
  source_key    text NOT NULL,             -- JSM issue key
  request_type  text, components text[], summary text, description_excerpt text,
  fingerprint   text,                      -- computed symptom signature (§4)
  cluster_id    uuid,                      -- set when correlated
  opened_at     timestamptz NOT NULL
);
```

### 2.3 `audit.*` — evaluations, journal, lineage

```sql
CREATE TABLE audit.clause_evaluation (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clause_id    uuid NOT NULL REFERENCES core.clause(id),
  spec_version int NOT NULL,
  evaluated_at timestamptz NOT NULL,
  verdict      text NOT NULL,              -- met | at_risk | breach | cannot_evaluate (stale/missing inputs — never silently 'met')
  detail       jsonb NOT NULL,             -- inputs used, thresholds, computed values
  evidence_ids uuid[]                      -- what it checked
);

CREATE TABLE audit.journal_entry (          -- append-only; UPDATE/DELETE revoked at the DB role level
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq         bigint GENERATED ALWAYS AS IDENTITY,
  risk_ref    text NOT NULL,               -- 'RSK-1180'
  severity    text NOT NULL, title text NOT NULL, body text NOT NULL,
  customer_ids uuid[] NOT NULL,            -- 1..n (cross-customer clusters span several)
  cluster_id  uuid,
  links       jsonb NOT NULL DEFAULT '[]'::jsonb,  -- clause refs, work items, CVEs, evidence
  movement    jsonb NOT NULL,              -- {from:'New', to:'Open·P1'}
  owner       text, due_at timestamptz,
  author_id   uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
```

### 2.4 `semantic.*` — derived, versioned, explainable
Materialized views (refreshed on ingest events) with the definitions checked into the repo:
`semantic.health_band`, `semantic.outcome_index`, `semantic.exposure`, `semantic.velocity_trend`,
`semantic.blocked_age`, `semantic.renewal_runway`, `semantic.version_drift`. Each has a
`definition_version` and a markdown definition page served behind the DERIVED badge.

---

## 3 · The engines on top of the layer

### 3.1 Control scheduler
Cron-per-control + event-triggered re-runs (e.g. Jira attachment webhook re-runs the gate check for
that engagement immediately). Every run writes `audit.clause_evaluation` (or control_evaluation for
non-clause controls); verdict transitions (met→at_risk, at_risk→breach, →cannot_evaluate) auto-draft
journal entries and decision-queue items.

### 3.2 Clause spec format (governed, versioned)

```yaml
clause: "§7.2"
instrument: SOW-14
name: Milestone gate — Release 4 evidence
tier: auto
test:
  all_of:
    - evidence: {requirement: uat_pack,     state: verified, within_working_days_of: gate_date, days: 5}
    - evidence: {requirement: release_note, state: verified, within_working_days_of: gate_date, days: 5}
inputs:
  gate_date: {source: salesforce, field: Milestone__c.Gate_Date__c}
remedy: {type: milestone_hold, amount: £340k}
on_breach: {raise: P1, notify: [csm, delivery_lead]}
```

Specs live in the DB (`core.clause.spec`) but are authored/reviewed through a PR-like flow with
commercial sign-off; every evaluation records the spec_version it ran against.

### 3.3 Correlation engine (Phase 4)
- **Blast radius**: `SELECT` over `core.deployment` for affected version ranges, joined to each
  customer's clause set for contractual re-scoring (remediation windows, change-notice obligations,
  freezes, credit caps) → liability-ranked table.
- **Symptom fingerprinting**: normalize JSM ticket text (strip customer-specific tokens), extract
  component refs + error signatures + time buckets → `core.ticket.fingerprint`; candidate clusters
  proposed when fingerprints match across ≥2 customers within a window; human confirms in v1.
- **Sequencing recommendation**: constraint check over patch windows vs clause deadlines vs freeze
  periods — deterministic and explainable, shown with its reasoning like the mock's
  "Halcyon first" card.

### 3.4 QBR claim linter
Runs at pack-assembly time over every figure: window check (`measurement.window_*` covers the
reporting period), verification check (all cited `evidence.state = 'verified'`, artifact versions
still match pins), freshness check (source lag within tolerance). Failures annotate the claim
in-place; the share action is blocked while unresolved flags exist.

---

## 4 · Build walkthrough (what we actually do, in order)

**Week 0–1 · Skeleton**
Repo `meridian/` — `cmd/connector`, `cmd/engine`, `cmd/api`, `internal/{staging,core,crosswalk,provenance}`,
`db/migrations` (sqlc or equivalent), `specs/clauses/`, `deployments/`. Postgres up, staging +
crosswalk + unmapped-queue migrations applied. Seed crosswalk by hand for the pilot CSM's accounts.

**Week 1–3 · First three connectors (pilot account scope)**
1. **Jira + JSM first** (same platform, one auth app, webhooks are easy wins): issues, sprints,
   attachments metadata, JSM SLAs. Proves webhook-fast-path/poll-for-truth pattern.
2. **Salesforce**: REST backfill of Account/Contract/Opportunity + 15-min poll (CDC later).
3. **Workday RaaS**: two reports (assignments+utilisation, project financials), 2-h pull,
   restatement-safe upserts.
Exit test: sidebar freshness dots real; unmapped-record queue visibly catching anything unmapped.

**Week 3–5 · Canonical + first clause end-to-end (Phase 0 exit)**
Projectors from staging → core for the entities above; `§7.2 milestone gate` spec authored;
evaluator runs on cadence + on attachment webhook; verdict transition writes a journal draft.
**Demo: delete/attach a UAT pack in Jira and watch the gate flip within a minute.**

**Week 5–8 · Evidence sources + measurements (feeds Phase 1)**
4. **Confluence connector**: page metadata + versions + labelled-page text; evidence pinning +
   stale-flip on edit.
5. **Drive connector**: shared-drive changes feed, revision pinning, folder-convention checker
   (first missing-artifact control beyond Jira).
Measurement pipelines: SLA cycles (JSM), crash-free/velocity (Jira), utilisation/margin (Workday),
CSAT (Salesforce). Semantic views v1 (health band, outcome index, exposure) with definition pages.

**Week 8+** · API + console build against the layer (Phases 1–3 of the project plan), then
deployment inventory + correlation engine (Phase 4).

### Definition of done for the data layer (before UI work leans on it)
- Every canonical row answers: *which staging rows produced you, when, from which source?*
- Killing any one connector degrades to visible staleness — zero silently-frozen numbers.
- Rebuild-from-staging reproduces canonical byte-for-byte (replay test in CI).
- Crosswalk coverage report ≥ 100% for pilot accounts; unmapped queue at zero or triaged.
