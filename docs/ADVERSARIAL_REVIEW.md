# Meridian — Adversarial Review (Four-Persona)
**28 Jul 2026 · reviewers: CCO · Client Success Director · Delivery Director · CS Leadership/Ops**
Method: four independent adversarial reviews run in parallel against the repo and the live API,
each attacking the platform's ability to support that persona's real decisions, with client
outcomes as the test. Full per-persona reports are summarised here; findings cite files/fields.

**Composite verdict:** the read-path architecture — semantic views, provenance discipline,
blast-radius and outcome computations — is the honest ~30% and worth keeping. The other ~70%
(controls, governance, decision closure, trend, client voice) currently exists as **fixtures
wearing the uniforms of engines**. The platform's own plan wrote the standard ("don't fake
automation", "fail visible, never fail silent", "no claim without a source record"); the build
violates all three today. Nothing here is fatal — but the fixes below are ordered by what
destroys trust first.

---

## 1 · Where all four reviewers converged

### C1. "Exposure at risk" is indefensible and inconsistent (CCO #1 · Ops risk #3)
Three concurrent definitions on three screens: KPI £14.9m (`SUM(ACV) WHERE breaches>0 OR
crit_risks>0`, handlers.go — whole-ACV on a binary trigger, partly driven by
`journal_entry.tone`, a *display* field); decision queue £19.4m (hand-typed
`exposure_pennies`, double-counting Northwind); correlation £13.0m (ACV over impacted rows).
The plan's own definition (§1.5: live clause remedies + weighted ACV-at-risk) is implemented
nowhere, while `clause.remedy_amount_pennies` sits unused. **A CCO quoting "exposure" gets a
different number per screen — checkable with a calculator in the board meeting.**

### C2. Zero of ~16 catalogued controls are live; the fixtures impersonate engines (Ops #B · all)
There is no evaluator, no scheduler, no engine binary. Every `clause_evaluation` row is seeded;
journal entries are authored by fictional `system:clause-monitor` / `system:renewal-control`
agents; "day 3 of 14" is a frozen string; `check_cadence_minutes` implies a scheduler that
doesn't exist. The flagship missing-artifact control is a hand-inserted `state='missing'` row.
"Five consecutive weeks >100% utilisation" and "margin plan 18%" — the load-bearing claims for
two directors' biggest decisions — exist only as journal prose, unreproducible from stored data.

### C3. The console is read-only; the decision loop never closes (CS Dir #1 · Ops #D)
Seven GET routes, zero POST. "+ RAISE RISK" and every decision-queue action button have **no
onClick handler**. No decision record exists (decided_by / decided_at / option chosen), no
overdue detection (`due_note` is prose), no done-state short of closing the whole risk. The
plan's own success metric — "fraction of surfaced decisions the CSM acts on" — is unmeasurable
by construction. The "append-only" journal cannot be appended to, and its single mutable
`state` column means real usage would *require* row mutation.

### C4. No client voice, no leading indicators — the quiet churner is invisible (CCO #2 · CS Dir #C)
CSAT exists only as free text in a note field and journal prose; zero measurement rows. No
stakeholder/sponsor entity, no contact recency, no survey pipeline. Every detector (bubble
score, velocity, clauses) requires the client to *generate activity* — a disengaging client's
dashboard **improves** all the way to the non-renewal call. Product telemetry (MAU, error
rates) is ingested but feeds no band, control, or alert. Replay test: Solent Marine would
surprise us again — every signal that could have fired 90 days earlier is free text, absent,
or one snapshot deep.

### C5. Everything is snapshot-deep and the snapshot has no writer (CCO #3 · CS Dir #2 · Ops #4)
`audit.signal_snapshot` is "written by a scheduled job" that does not exist. From next week the
RAG board silently diffs against 21 Jul forever while claiming "this week"; customers without
snapshots show standing state as fabricated deltas (`COALESCE(ss.*, 0)`). `v_measure_latest`
discards history, so no trend exists for any metric except velocity — no NRR, no attainment
slope, no utilisation streaks, no band trajectory.

### C6. Fail-silent defaults — the exact failure the plan forbids (CCO #4 · Ops #A)
`COALESCE(utilisation_pct, 100)`: a dead Workday feed makes every account look
capacity-healthy. `cannot_evaluate` verdicts count as neither breach nor at-risk, so **stale
evidence improves the health band**. NULL margin (5 of 8 accounts) renders as unremarkable.
Stale measurements stay "latest" forever with no cutoff. Freshness dots read from a fixture
table while `staging.source_record` holds zero rows — provenance is currently a costume.

### C7. Aggregates computed over partial data, presented as portfolio truth (Delivery #1)
"Capacity gap 1.0 FTE" sums the one engagement (of eight) that has assignment rows — while
Kestrel runs at 108% and Northwind's own capacity-plan artifact says 21 needed / 18.5 assigned
(two irreconcilable FTE truths on one screen). No coverage denominator appears anywhere. KPI
tiles for breaches/exposure/capacity are colored crit/warn **unconditionally, even at zero**.

### C8. Outcome alignment is a schema hook, not a computed audit (Delivery #C)
`delivery_outcome.contracted_outcome_id` and `assignment.delivery_outcome_id` exist — but no
view audits either direction. In the seed: the **worst contracted outcome on the flagship
account (legacy decommission, 43% attainment) has zero delivery outcomes' FTE behind it and
renders as a blank, not an alarm**; the largest FTE block (CVE remediation, 8 FTE) is labelled
"operational — supports no contracted outcome" because clause-defending work is structurally
unrepresentable as aligned; seven of eight clients have no delivery outcomes at all, surfaced
only as a passive empty state. The misalignment the platform exists to prevent is invisible in
the platform.

### C9. Definition drift: one concept, three homes, contradictions on one screen (Ops #A)
`core.definition` holds 4 keys; health band, outcome status, exposure, outcome index and bubble
score are defined in SQL comments, handler code, or nowhere — while the UI hard-codes its own
divergent thresholds. Concrete contradictions: Kestrel at 108% utilisation is "watch" (SQL),
crit (signal row), warn (360 tile); Verdant shows **0/2 outcomes on track** in the KPI strip
while the same outcomes render amber "behind" on the 360; three different renewal windows
(90/110-45/180 days) coexist; the bubble-score caption hard-codes a formula the view owns;
'behind' on a 99.5% crash-free SLA mathematically covers anything down to 89.55%.

### C10. The platform detects failure, not approaching failure (Delivery #2)
No milestone/gate entity with future dates exists; the £340k breach was detected after the
window closed, and the agreed 14 Aug re-gate lives only in journal prose — not machine-readable,
so the same failure will recur. No gate-runway view ("gates due ≤30d × evidence still
missing"). Renewal `notice_days` is stored and used by nothing — Verdant shows 144 days of
runway when its real decision window is 84.

### C11. Identity spine assumes 1 customer = 1 engagement = 1 instrument (Ops #5 · CCO #D7)
`v_customer_signal` joins instruments per engagement; modelling Castellan's "MSA + 3 SOWs"
honestly would duplicate customers and double-count ACV in every KPI; `customer360` silently
takes `header[0]`. Zero PK/FK/UNIQUE/CHECK constraints anywhere. This breaks the *totals*
first, at exactly the 8→50 scale-out moment.

### C12. Three QBRs due inside 21 days; no QBR surface, no interim path (CS Dir #3)
The seed itself schedules one ("QBR on 12 Aug"); Halcyon renews in 37 days. The
window-mismatch defect the QBR linter exists to catch is live in the data today (30d
availability figure vs 91d period) and nothing can catch it.

---

## 2 · Decision audit rollup

| Persona | Can decide today | Partial | Cannot decide |
|---|---|---|---|
| CCO | 1 of 7 (where to intervene) | 3 | churn forecast · NRR · board exposure |
| CS Director | 0 of 7 | 3 | decisions queue · QBR readiness · quiet-account detection · coaching record |
| Delivery Director | 0 of 7 | 4 | people moves · gate pre-warning · margin decomposition |
| Per-level (Ops) | each level has exactly one genuinely-supported decision | — | each level has one pretended decision |

What each level *can* genuinely do today: CCO — ranked portfolio attention; CS Director —
renewals lacking a motion; Delivery Director — CVE patch sequencing (blast radius is real SQL);
CSM — contracted-outcome attainment with provenance. That's the honest core to build from.

---

## 3 · Prioritised remediation

### Phase A — Stop being wrong (days)
1. **One exposure definition.** Implement `semantic.v_exposure` per the plan (§1.5): live
   clause remedies (`remedy_amount_pennies`) + a separately-labelled "ACV under watch";
   de-duplicate cross-customer risks; KPI, decision queue and correlation all read it.
2. **Fail visible.** Remove `COALESCE(util,100)`; `cannot_evaluate` counts as at-risk; NULL
   margin/util renders "cannot evaluate"; staleness cutoff on `v_measure_latest`; coverage
   labels on every partial aggregate ("capacity gap · 1 of 8 engagements reporting"); KPI
   tones conditional on value.
3. **Tell the truth on screen.** Badge every seeded evaluation "manual/seed" until an evaluator
   exists; remove fictional `system:*` authors; single home for every definition and threshold
   in `core.definition` (health band, outcome status, exposure, bubble score, renewal windows)
   with the UI consuming it.
4. **Unbreak the weekly ritual.** Snapshot writer (20-line scheduled upsert) + staleness guard
   that suppresses deltas; `csm_name` in `/api/signal` + group-by-CSM; structured
   `due_at` on journal entries + OVERDUE pill + sort by urgency, not money.

### Phase B — Close the loop (1–2 weeks)
5. **Write path + decision state machine.** `POST /api/journal` (append-per-movement, not row
   mutation), decision records (options, decided_by/at, chosen, verify_by), wire the three dead
   buttons. Until "acted" is recorded, the platform can't measure its own success metric.
6. **`semantic.v_outcome_coverage`.** Contracted outcomes × delivery outcomes × committed FTE,
   both directions; unmet outcome with zero capacity = crit pill, not a blank. Add
   `delivery_outcome → clause` linkage so clause-defending work counts as aligned.
7. **Gate runway.** `core.milestone` with future gate dates (Salesforce `Gate_Date__c` is
   already named in the spec format) + `v_gate_runway`: gates due ≤30d with evidence not
   verified, days remaining. Converts the flagship control from post-mortem to pre-mortem.
8. **Interim QBR brief.** Read-only per-customer export (outcomes with windows, clause verdicts,
   open risks, renewal position, every figure with source ref) + the one cheapest lint:
   measurement window ≠ reporting period. Rescues the 12 Aug QBR.

### Phase C — Earn the claims (weeks)
9. **One real control end-to-end** (the plan's own Phase-0 exit): §7.2 evaluator on a schedule,
   reading `core.evidence`, writing `clause_evaluation` (incl. `cannot_evaluate` on stale
   sources), drafting the journal entry. One honest control beats sixteen seeded ones.
10. **Client-voice layer.** CSAT as measurement rows + trend; silence/engagement control
    (days-since-last-inbound, `waiting_client` dwell); stakeholder entity; adoption-drop
    control on existing telemetry. Two bands per account: "are we delivering" and "is the
    client getting value".
11. **Commercial ledger.** Change orders as rows (kill `delta_label`), instrument history →
    computed NRR/expansion/contraction; margin decomposition feeds (plan vs actual, rate,
    billable, rework) via the Workday RaaS reports already specified.
12. **Identity spine.** Aggregate instruments/engagements correctly in the signal views,
    app-layer PK/uniqueness enforcement, `measurement.source_ref` pointing at real staging rows.
13. **Platform-gap severity.** `blocks_kind` (clause|gate|incident|feature_request) +
    optional `clause_id` on gap links; rank by (worst-blocked, reach) — make the served
    definition true, or change it.

---

## 3a · Remediation & adversarial re-review (29 Jul 2026)

All twelve converged findings were implemented across the data layer, backend and
frontend, then **re-attacked by the same four personas plus a regression critic** (workflow
`adversarial-reverify`, high effort, against the changed code + live API). Result: **23 of the
original findings confirmed closed**, with the reviewers surfacing 9 new latent issues and 4
partials — the load-bearing ones were then fixed in a second pass:

**Closed (verified in code + API):** single `v_exposure` definition (remedy vs ACV-under-watch,
deduped, uncapped flagged); client-voice layer (CSAT trend, stakeholders, silence) — Solent's
7.8→6.1 collapse now visible; `v_util_streak` (5-week over-util is derived, not prose); fail-visible
band (no COALESCE-to-100, `cannot_evaluate` escalates, `missing_signals` surfaced); write path
(raise → move → decide, append-only `journal_movement` + `decision`); snapshot writer + staleness;
decision queue sorted by `due_at`; client-agreed outcome floors (99.1% now `at_risk`); CSM cut;
QBR brief + window-lint; forward gate runway; `v_outcome_coverage` unaligned flag; 15 definitions
served from the lake with thresholds the UI consumes; `method='evaluated'` badges + a real §7.2
evaluator on boot; provenance rows; `v_engagement_contract` aggregation.

**New issues found by the re-review and fixed in the second pass:**
- **`v_exposure` double-counted remedy per engagement** (critic) — re-grained to one row per
  customer via aggregation, so a multi-SOW customer can't inflate the portfolio KPI.
- **Correlation "ACV exposed £13m"** was a third loss-headline contradicting the exposure
  definition — relabelled "ACV in blast radius · scope, not loss" (view + banner).
- **`gates_at_risk` dropped overdue gates** — KPI now counts `days_to_gate ≤ 30` including overdue.
- **RAG baseline could collapse to one day** on consecutive-day boots — baseline is now the latest
  snapshot ≥6 days old (true weekly line), and stale baselines **hold** the deltas (not just warn),
  threshold read from `core.definition rag_snapshot`.
- **Sponsor aggregation** used column-wise `MAX` (could pair one person's status with another's
  sentiment) — now selects the single most-concerning sponsor row.
- **`missing_signals` never rendered** — capacity cell now shows "margin: no data" instead of a
  silent blank; Customer 360 util/index thresholds read from the lake via `useThr`.
- **State-move endpoint had no UI** — Journal entries now have state-advance controls.

**Known partials left as follow-ons (documented, not silently dropped):** staging provenance rows
exist but aren't yet wired to a UI drill-through (badges still resolve conceptually, not by click);
freshness dots still read fixture `lag_seconds` rather than computed age; `useThr` now covers
Signal + RAG + Customer 360 but not every colour decision in every view.

## 4 · The principle the review keeps returning to

Every reviewer independently found the same pattern: **the platform documents rules it does not
apply** — velocity "only matters when correlated" (served definition; UI alarms raw), gap
severity "inherits from the worst thing blocked" (computed nowhere), "append-only" (mutable),
"no claim without a source record" (staging empty), "don't fake automation" (sixteen seeded
controls). A platform whose product is *trust in derived claims* cannot afford daylight between
its stated rules and its computed behaviour. Close the gap in whichever direction is honest:
implement the rule, or rewrite the rule.
