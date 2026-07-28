// Typed client for the Meridian API. All figures come from the data lake via
// the Go backend — this app holds no data of its own.

export type Tone = 'good' | 'warn' | 'crit' | 'muted'
export type HealthBand = 'on_track' | 'watch' | 'at_risk'

export interface SourceStatus {
  source_system: string
  last_success: string | null
  lag_seconds: number | null
}

export interface SignalKpis {
  total_acv_pennies: number | null
  engagements: number
  outcomes_on_track: number | null
  outcomes_total: number | null
  clause_breaches: number | null
  clauses_at_risk: number | null
  exposure_pennies: number | null
  capacity_gap_fte: number | null
  renewals_90d: number | null
}

export interface SignalCustomer {
  customer_id: string
  engagement_id: string
  name: string
  mark: string
  sector: string | null
  health_band: HealthBand
  outcomes_on_track: number
  outcomes_total: number
  clause_breaches: number
  clauses_at_risk: number
  clauses_total: number
  utilisation_pct: number | null
  margin_pct: number | null
  velocity_delta_pct: number | null
  vehicle_label: string | null
  acv_pennies: number | null
  renewal_date: string | null
  renewal_days: number | null
  delta_label: string | null
  open_risks: number
  crit_risks: number
  velocity_spark: number[]
}

export interface Decision {
  risk_ref: string
  severity: string
  tone: Tone
  title: string
  scope_label: string
  owner: string
  due_note: string | null
  exposure_pennies: number | null
  action_label: string
  action_view: string | null
}

export interface Renewal {
  customer_id: string
  name: string
  renewal_days: number
  acv_pennies: number | null
  opportunity_open: boolean | null
  note: string | null
}

export interface SignalResponse {
  kpis: SignalKpis
  customers: SignalCustomer[]
  decisions: Decision[]
  renewals: Renewal[]
}

export interface Customer360Header {
  customer_id: string
  engagement_id: string
  name: string
  mark: string
  sector: string | null
  health_band: HealthBand
  outcomes_on_track: number
  outcomes_total: number
  clause_breaches: number
  clauses_at_risk: number
  utilisation_pct: number | null
  margin_pct: number | null
  vehicle_label: string | null
  acv_pennies: number | null
  tcv_pennies: number | null
  renewal_date: string | null
  renewal_days: number | null
  csm_name: string | null
  delivery_lead: string | null
  instrument_ref: string | null
  gates_passed: number | null
  gates_total: number | null
  outcome_index: number | null
  assigned_fte: number | null
  planned_fte: number | null
}

export interface OutcomeRow {
  name: string
  target_display: string
  actual_display: string | null
  status: 'met' | 'behind' | 'at_risk' | 'unknown'
  attainment_pct: number
  measure_source: string
  source_ref: string | null
}

export interface ClauseRow {
  clause_ref: string
  clause_name: string
  test_description: string
  verdict: 'met' | 'at_risk' | 'breach' | 'cannot_evaluate'
  evidence_note: string | null
  money_note: string | null
  evaluated_at: string
  category: string
  remedy_type: string | null
}

export interface TeamRow {
  role: string
  planned_fte: number
  assigned_fte: number
  utilisation_pct: number
  flag: string | null
  delivery_outcome: string | null
  delivery_status: string | null
}

export interface DeliveryOutcomeRow {
  name: string
  description: string | null
  status: 'on_track' | 'at_risk' | 'late' | 'done'
  target_date: string | null
  supports_contracted: string | null
  committed_fte: number | null
}

export interface ArtifactRow {
  kind: string
  title: string
  summary: string | null
  status: string
  source_system: string
  source_ref: string
  url: string
  version: string | null
  authored_by: string | null
  authored_at: string
}

export interface TelemetryRow {
  product_id: string
  metric: string
  value: number
  display_value: string | null
  baseline: number | null
  source_system: string
  source_ref: string | null
  window_end: string
}

export interface ProductRow {
  product_id: string
  name: string
  kind: string
  stage: string
  launched_at: string | null
  source_url: string | null
  source_ref: string | null
  depends_on: string | null
  telemetry: TelemetryRow[]
}

export interface VelocityPoint {
  value: number
  source_ref: string | null
  window_end: string
}

export interface EpicRow {
  source_key: string
  title: string
  state: string
  gate_ref: string | null
  blocked_days: number | null
}

export interface EvidenceRow {
  requirement: string
  state: 'missing' | 'attached' | 'verified' | 'stale'
  due_at: string | null
  verified_at: string | null
  verified_by: string | null
  artifact_kind: string | null
  artifact_url: string | null
  pinned_version: string | null
  clause_ref: string | null
}

export interface Customer360Response {
  header: Customer360Header
  outcomes: OutcomeRow[]
  clauses: ClauseRow[]
  team: TeamRow[]
  delivery_outcomes: DeliveryOutcomeRow[]
  velocity: VelocityPoint[]
  epics: EpicRow[]
  evidence: EvidenceRow[]
  artifacts: ArtifactRow[]
  products: ProductRow[]
}

export interface JournalLink {
  journal_id: string
  text: string
  tone: Tone
}

export interface JournalEntry {
  id: string
  risk_ref: string
  severity: string
  tone: Tone
  title: string
  body: string
  scope_label: string
  cluster_id: string | null
  movement_from: string
  movement_to: string
  state: string
  owner: string
  due_note: string | null
  created_at: string
  author: string
  links: JournalLink[]
}

export interface Vulnerability {
  id: string
  ref: string
  title: string
  description: string | null
  disclosed_at: string
  fixed_in_version: string | null
  service_name: string
}

export interface BlastRow {
  customer_id: string
  customer_name: string
  mark: string
  version: string
  env_label: string
  exposure: string
  impact: 'impacted' | 'potentially_impacted' | 'not_vulnerable'
  security_clause_ref: string | null
  security_clause_name: string | null
  remedy_type: string | null
  acv_pennies: number | null
}

export interface MatrixCell {
  service: string
  mark: string
  customer_name: string
  status: 'vulnerable' | 'drift' | 'patched' | 'none'
}

export interface SymptomRow {
  source_key: string
  summary: string
  fingerprint: string | null
  opened_at: string
  customer_name: string
  mark: string
  customers_sharing: number
}

export interface RationaleRow {
  customer_id: string
  evidence_kind: 'deployment' | 'artifact' | 'ticket' | 'telemetry'
  rationale: string
  confidence: 'confirmed' | 'probable' | 'possible'
  evidence_label: string | null
  evidence_source: string | null
  artifact_url: string | null
  artifact_kind: string | null
}

export interface CorrelationResponse {
  vulnerability: Vulnerability | null
  affected: BlastRow[]
  matrix: MatrixCell[]
  symptoms: SymptomRow[]
  rationale: RationaleRow[]
}

export interface RagTopic {
  customer_id: string
  risk_ref: string
  title: string
  tone: Tone
  state: string
  due_note: string | null
  created_at: string
}

export interface RagMovementRow {
  customer_id: string
  name: string
  mark: string
  sector: string | null
  health_band: HealthBand
  prev_band: HealthBand | null
  snapshot_date: string | null
  breaches_delta: number
  at_risk_delta: number
  outcomes_delta: number
  risks_delta: number
  util_delta: number | null
  velocity_delta_pct: number | null
  clause_breaches: number
  outcomes_on_track: number
  outcomes_total: number
  utilisation_pct: number | null
  open_risks: number
  acv_pennies: number | null
  renewal_days: number | null
  topics: RagTopic[]
}

export interface BubblingIncident {
  customer_id: string
  customer_name: string
  mark: string
  source_key: string
  summary: string
  fingerprint: string | null
  status: string
  priority: string
  comment_count: number
  reopen_count: number
  participant_count: number
  customers_sharing: number
  bubble_score: number
  opened_at: string
  last_activity_at: string | null
}

export interface RagResponse {
  movement: RagMovementRow[]
  bubbling: BubblingIncident[]
}

export interface WorkloadRow {
  source_key: string
  source_system: 'jira' | 'jsm'
  kind: string
  title: string
  status: string
  gate_ref: string | null
  blocked_days: number | null
  delivery_outcome: string | null
  priority: string | null
}

export interface PlatformGapRow {
  name: string
  description: string
  status: string
  eta: string | null
  owner: string | null
  blocking_note: string
  linked_ref: string | null
  reach: number
}

export interface DeliveryRisk {
  risk_ref: string
  severity: string
  tone: Tone
  title: string
  state: string
  owner: string
  due_note: string | null
  exposure_pennies: number | null
  created_at: string
}

export interface DefinitionRow {
  key: string
  title: string
  definition: string
  formula: string | null
  inputs: string | null
}

export interface DeliveryResponse {
  who: {
    customer_id: string
    engagement_id: string
    name: string
    mark: string
    sector: string | null
    health_band: HealthBand
    velocity_delta_pct: number | null
  }
  workload: WorkloadRow[]
  delivery_outcomes: DeliveryOutcomeRow[]
  gaps: PlatformGapRow[]
  risks: DeliveryRisk[]
  definitions: DefinitionRow[]
}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(path)
  if (!res.ok) throw new Error(`${path}: ${res.status} ${await res.text()}`)
  return res.json() as Promise<T>
}

export const api = {
  health: () => get<{ ok: boolean; sources: SourceStatus[] }>('/api/health'),
  signal: () => get<SignalResponse>('/api/signal'),
  customer: (id: string) => get<Customer360Response>(`/api/customers/${id}`),
  journal: () => get<{ entries: JournalEntry[] }>('/api/journal'),
  correlation: () => get<CorrelationResponse>('/api/correlation'),
  rag: () => get<RagResponse>('/api/rag'),
  delivery: (id: string) => get<DeliveryResponse>(`/api/customers/${id}/delivery`),
}

// Formatting helpers ---------------------------------------------------------

export function money(pennies: number | null | undefined): string {
  if (pennies == null) return '—'
  const m = pennies / 100_000_000
  if (Math.abs(m) >= 1) return `£${m.toFixed(1)}m`
  return `£${Math.round(pennies / 100_000)}k`
}

export function bandLabel(b: HealthBand): string {
  return b === 'on_track' ? 'On track' : b === 'watch' ? 'Watch' : 'At risk'
}

export function bandTone(b: HealthBand): Tone {
  return b === 'on_track' ? 'good' : b === 'watch' ? 'warn' : 'crit'
}

export function verdictTone(v: string): Tone {
  if (v === 'breach' || v === 'at_risk_hard') return 'crit'
  if (v === 'at_risk' || v === 'cannot_evaluate' || v === 'behind') return 'warn'
  if (v === 'met') return 'good'
  return 'muted'
}

export function ago(iso: string | null): string {
  if (!iso) return '—'
  const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60_000)
  if (mins < 60) return `${mins} min`
  if (mins < 60 * 24) return `${Math.round(mins / 60)} h`
  return `${Math.round(mins / (60 * 24))} d`
}

export function shortDate(iso: string | null): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}
