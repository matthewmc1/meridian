import { useEffect, useState } from 'react'
import {
  api, bandLabel, bandTone, money, shortDate,
  type DeliveryResponse, type SignalCustomer, type WorkloadRow,
} from '../api'

const STATUS_ORDER = ['blocked', 'gate', 'in_progress', 'open', 'waiting_client', 'waiting_us', 'not_started', 'done']
const STATUS_LABEL: Record<string, string> = {
  blocked: 'Blocked', gate: 'At gate', in_progress: 'In progress', open: 'Open (service desk)',
  waiting_client: 'Waiting on client', waiting_us: 'Waiting on us', not_started: 'Not started', done: 'Done',
}
const STATUS_TONE: Record<string, string> = {
  blocked: 'crit', gate: 'crit', in_progress: 'warn', open: 'warn',
  waiting_client: 'muted', waiting_us: 'warn', not_started: 'muted', done: 'good',
}

export default function Delivery({
  customerId, onPick,
}: {
  customerId: string | null
  onPick: (id: string) => void
}) {
  const [customers, setCustomers] = useState<SignalCustomer[]>([])
  const [data, setData] = useState<DeliveryResponse | null>(null)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    api.signal().then((s) => setCustomers(s.customers)).catch((e) => setErr(String(e)))
  }, [])

  const effectiveId = customerId ?? customers[0]?.customer_id ?? null

  useEffect(() => {
    if (!effectiveId) return
    setData(null)
    api.delivery(effectiveId).then(setData).catch((e) => setErr(String(e)))
  }, [effectiveId])

  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!data) return <div className="loading">querying delivery workload…</div>

  const w = data.who
  const grouped = STATUS_ORDER
    .map((s) => ({ status: s, items: data.workload.filter((x) => x.status === s) }))
    .filter((g) => g.items.length > 0)

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow">
            Delivery &amp; risk · all work by status · no sprint lens
          </div>
          <div className="page-title" style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
            <span className={`mark ${bandTone(w.health_band)}`} style={{ width: 34, height: 34, fontSize: 12 }}>{w.mark}</span>
            {w.name}
            <span className={`pill ${bandTone(w.health_band)}`}>{bandLabel(w.health_band)}</span>
          </div>
        </div>
        <select
          className="btn-ghost mono"
          value={effectiveId ?? ''}
          onChange={(e) => onPick(e.target.value)}
          style={{ paddingRight: 8 }}
        >
          {customers.map((c) => (
            <option key={c.customer_id} value={c.customer_id}>{c.name}</option>
          ))}
        </select>
      </div>

      <div className="grid-2" style={{ marginBottom: 10 }}>
        <div className="panel">
          <div className="panel-head">
            Delivery outcomes — what the work is driving
            <span className="panel-note">distinct from contracted outcomes</span>
          </div>
          {data.delivery_outcomes.length === 0 && (
            <div style={{ padding: 14, font: "400 12px/1.5 'Instrument Sans',sans-serif", color: 'var(--faint)' }}>
              No delivery outcomes configured for this engagement yet.
            </div>
          )}
          {data.delivery_outcomes.map((d) => {
            const t = d.status === 'on_track' || d.status === 'done' ? 'good' : d.status === 'at_risk' ? 'warn' : 'crit'
            return (
              <div key={d.name} style={{ padding: '10px 14px', borderBottom: '1px solid var(--line2)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span className={`pill ${t}`}>{d.status.replace('_', ' ')}</span>
                  <span style={{ font: "500 12.5px/1.3 'Instrument Sans',sans-serif", flex: 1 }}>{d.name}</span>
                  {d.committed_fte != null && <span className="mono" style={{ fontSize: 10.5, color: 'var(--muted)' }}>{d.committed_fte} FTE</span>}
                  {d.target_date && <span className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>target {shortDate(d.target_date)}</span>}
                </div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 4 }}>
                  {d.supports_contracted ? `supports contracted outcome: ${d.supports_contracted}`
                    : d.defends_clause ? `defends clause ${d.defends_clause}`
                    : 'operational — supports no contracted outcome directly'}
                </div>
              </div>
            )
          })}
        </div>

        <div className="panel">
          <div className="panel-head">
            Risks for this client
            <span className="panel-note">open journal entries · see definitions below</span>
          </div>
          {data.risks.length === 0 && (
            <div style={{ padding: 14, font: "400 12px/1.5 'Instrument Sans',sans-serif", color: 'var(--faint)' }}>
              No open risks — closed history lives in the Risk journal.
            </div>
          )}
          {data.risks.map((r) => (
            <div key={r.risk_ref} style={{ padding: '10px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', alignItems: 'center', gap: 10 }}>
              <span className={`pill ${r.tone}`}>{r.severity}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ font: "500 12.5px/1.3 'Instrument Sans',sans-serif", whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.title}</div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 3 }}>
                  {r.risk_ref} · {r.state} · {r.owner} {r.due_note ? `· ${r.due_note}` : ''}
                </div>
              </div>
              {r.exposure_pennies != null && (
                <span className="mono" style={{ fontSize: 11.5, fontWeight: 500, color: 'var(--ink2)' }}>{money(r.exposure_pennies)}</span>
              )}
            </div>
          ))}
        </div>
      </div>

      <div className="grid-2" style={{ marginBottom: 10 }}>
        <div className="panel">
          <div className="panel-head">
            Outcome coverage
            <span className="panel-note">unmet outcome with 0 FTE = unaligned</span>
          </div>
          {data.coverage.map((c) => {
            const st = c.outcome_status === 'met' ? 'good' : c.outcome_status === 'behind' ? 'warn' : c.outcome_status === 'at_risk' ? 'crit' : 'muted'
            return (
              <div key={c.outcome_name} style={{ padding: '9px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', alignItems: 'center', gap: 10 }}>
                <span className={`pill ${st}`}>{c.outcome_status.replace('_', ' ')}</span>
                <span style={{ font: "400 12px/1.3 'Instrument Sans',sans-serif", flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.outcome_name}</span>
                <span className="mono" style={{ fontSize: 10.5, color: c.committed_fte === 0 && c.unaligned ? 'var(--crit)' : 'var(--muted)' }}>{c.committed_fte} FTE</span>
                {c.unaligned && <span className="pill crit" title="At-risk outcome with no committed capacity behind it">unaligned</span>}
              </div>
            )
          })}
        </div>

        <div className="panel">
          <div className="panel-head">
            Gate runway <span className="panel-note">pre-mortem: gate at risk before the date</span>
          </div>
          {data.gates.length === 0 && (
            <div style={{ padding: 14, font: "400 12px/1.5 'Instrument Sans',sans-serif", color: 'var(--faint)' }}>No forward gates scheduled.</div>
          )}
          {data.gates.map((g) => {
            const overdue = g.days_to_gate < 0
            const t = overdue || (!g.evidence_ready && g.days_to_gate <= 10) ? 'crit' : !g.evidence_ready && g.days_to_gate <= 30 ? 'warn' : 'good'
            return (
              <div key={g.name} style={{ padding: '9px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', alignItems: 'center', gap: 10 }}>
                <span className={`mono tone-${t}`} style={{ fontSize: 12.5, fontWeight: 600, width: 62, flex: 'none' }}>{overdue ? `${-g.days_to_gate}d over` : `${g.days_to_gate}d`}</span>
                <span style={{ font: "400 12px/1.3 'Instrument Sans',sans-serif", flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{g.name}</span>
                <span className={`pill ${g.evidence_ready ? 'good' : 'crit'}`}>{g.evidence_ready ? 'ready' : 'evidence missing'}</span>
              </div>
            )
          })}
        </div>
      </div>

      <div className="panel" style={{ marginBottom: 10 }}>
        <div className="panel-head">
          Platform gaps blocking this client
          <span className="panel-note">ours to fix — ranked by worst thing blocked, then reach</span>
        </div>
        {data.gaps.length === 0 && (
          <div style={{ padding: 14, font: "400 12px/1.5 'Instrument Sans',sans-serif", color: 'var(--faint)' }}>
            No platform gaps recorded against this client.
          </div>
        )}
        {data.gaps.map((g) => (
          <div key={g.name} style={{ padding: '11px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', gap: 12, alignItems: 'flex-start' }}>
            <span className={`pill ${g.worst_blocks_kind === 'clause' ? 'crit' : g.worst_blocks_kind === 'gate' ? 'crit' : g.worst_blocks_kind === 'incident' ? 'warn' : 'muted'}`}>
              {g.worst_blocks_kind.replace('_', ' ')}
            </span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ font: "500 12.5px/1.3 'Instrument Sans',sans-serif" }}>{g.name}
                <span className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', marginLeft: 8 }}>{g.status.replace('_', ' ')}</span>
              </div>
              <div style={{ font: "400 11.5px/1.45 'Instrument Sans',sans-serif", color: 'var(--muted)', marginTop: 3 }}>
                <strong style={{ color: 'var(--ink2)', fontWeight: 500 }}>Blocks here ({g.blocks_kind.replace('_', ' ')}):</strong> {g.blocking_note}
              </div>
            </div>
            <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', textAlign: 'right', flex: 'none' }}>
              blocks {g.reach} client{g.reach === 1 ? '' : 's'}
              {g.eta ? <><br />ETA {shortDate(g.eta)}</> : null}
              {g.linked_ref ? <><br />{g.linked_ref}</> : null}
            </div>
          </div>
        ))}
      </div>

      <div className="panel" style={{ marginBottom: 10 }}>
        <div className="panel-head">
          All work for this client · by status
          <span className="panel-note">Jira delivery work + JSM service tickets, one list</span>
        </div>
        {grouped.map((g) => (
          <div key={g.status}>
            <div style={{ padding: '8px 14px', background: 'var(--surface3)', borderBottom: '1px solid var(--line2)', display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className={`pill ${STATUS_TONE[g.status] ?? 'muted'}`}>{STATUS_LABEL[g.status] ?? g.status}</span>
              <span className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>{g.items.length}</span>
            </div>
            {g.items.map((x) => <WorkRow key={x.source_key} x={x} />)}
          </div>
        ))}
      </div>

      <div className="panel">
        <div className="panel-head">
          Definitions — how these numbers are computed
          <span className="panel-note">served from the lake (core.definition), not hard-coded</span>
        </div>
        <div style={{ padding: 14, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {data.definitions.map((d) => (
            <div key={d.key} style={{ border: '1px solid var(--line)', borderRadius: 6, padding: '12px 13px', background: 'var(--surface2)' }}>
              <div style={{ font: "600 12.5px/1.3 'Instrument Sans',sans-serif", marginBottom: 6 }}>{d.title}</div>
              <div style={{ font: "400 11.5px/1.55 'Instrument Sans',sans-serif", color: 'var(--muted)' }}>{d.definition}</div>
              {d.formula && (
                <div className="mono" style={{ fontSize: 10, color: 'var(--ink2)', marginTop: 8, padding: '6px 8px', background: 'var(--surface3)', borderRadius: 4 }}>
                  {d.formula}
                </div>
              )}
              {d.inputs && <div className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', marginTop: 6 }}>inputs: {d.inputs}</div>}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function WorkRow({ x }: { x: WorkloadRow }) {
  return (
    <div style={{ padding: '9px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', alignItems: 'center', gap: 10 }}>
      <span className="mono" style={{ fontSize: 10.5, fontWeight: 500, color: 'var(--muted)', width: 70, flex: 'none' }}>{x.source_key}</span>
      <span className="src-badge">{x.source_system}</span>
      <span style={{ font: "400 12px/1.3 'Instrument Sans',sans-serif", flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{x.title}</span>
      {x.gate_ref && <span className="pill crit">gates {x.gate_ref}</span>}
      {x.priority === 'high' && <span className="pill crit">high</span>}
      {x.blocked_days != null && (
        <span className="mono tone-crit" style={{ fontSize: 10.5, fontWeight: 500, flex: 'none' }}>{x.blocked_days} d blocked</span>
      )}
      <span className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', flex: 'none', maxWidth: 200, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
        {x.delivery_outcome ? `→ ${x.delivery_outcome}` : ''}
      </span>
    </div>
  )
}
