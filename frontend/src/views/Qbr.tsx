import { useEffect, useState } from 'react'
import { api, bandLabel, bandTone, money, shortDate, verdictTone, outcomeTone, type QbrResponse, type SignalCustomer } from '../api'

// Interim QBR brief assembled from the lake — every figure with its source, plus
// the one cheapest claim lint: outcome measurement windows that don't cover the
// reporting quarter (the exact defect the full linter will own). Bridges the gap
// until the Phase-3 pipeline ships, so packs aren't retyped unlinted.
export default function Qbr({ customerId, onPick }: { customerId: string | null; onPick: (id: string) => void }) {
  const [customers, setCustomers] = useState<SignalCustomer[]>([])
  const [data, setData] = useState<QbrResponse | null>(null)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => { api.signal().then((s) => setCustomers(s.customers)).catch((e) => setErr(String(e))) }, [])
  const id = customerId ?? customers[0]?.customer_id ?? null
  useEffect(() => {
    if (!id) return
    setData(null)
    api.qbr(id).then(setData).catch((e) => setErr(String(e)))
  }, [id])

  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!data) return <div className="loading">assembling QBR brief from the lake…</div>

  const h = data.header
  const flags = data.outcomes.filter((o) => o.window_flag).length
  const breaches = data.clauses.filter((c) => c.verdict === 'breach').length

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow">Assembled from the lake · every figure carries its source · 0 manual entry</div>
          <div className="page-title" style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
            <span className={`mark ${bandTone(h.health_band)}`} style={{ width: 34, height: 34, fontSize: 12 }}>{h.mark}</span>
            {h.name} — QBR brief
            <span className={`pill ${bandTone(h.health_band)}`}>{bandLabel(h.health_band)}</span>
          </div>
        </div>
        <select className="btn-ghost mono" value={id ?? ''} onChange={(e) => onPick(e.target.value)}>
          {customers.map((c) => <option key={c.customer_id} value={c.customer_id}>{c.name}</option>)}
        </select>
      </div>

      {(flags > 0 || breaches > 0) && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '11px 14px', borderRadius: 6, background: 'var(--warnBg)', border: '1px solid var(--warn)', marginBottom: 14 }}>
          <span className="mono" style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--warn)', flex: 'none' }}>
            {flags + breaches} claim{flags + breaches === 1 ? '' : 's'} to review
          </span>
          <span style={{ font: "400 12px/1.4 'Instrument Sans',sans-serif", color: 'var(--ink2)' }}>
            {flags > 0 && `${flags} outcome measurement window(s) shorter than the reporting quarter. `}
            {breaches > 0 && `${breaches} clause breach flagged. `}
            Both are surfaced in place before this pack goes to the client.
          </span>
        </div>
      )}

      <div className="grid-2" style={{ marginBottom: 10 }}>
        <div className="kpi"><div className="kpi-label">Contract value</div><div className="kpi-value tone-ink">{money(h.acv_pennies)}</div><div className="kpi-sub">renews {shortDate(h.renewal_date)}</div></div>
        <div className="kpi"><div className="kpi-label">Outcomes on track</div><div className="kpi-value tone-ink">{h.outcomes_on_track}/{h.outcomes_total}</div><div className="kpi-sub">CSM {h.csm_name} · lead {h.delivery_lead}</div></div>
      </div>

      <div className="panel" style={{ marginBottom: 10 }}>
        <div className="panel-head">Outcome performance <span className="panel-note">measurement window vs reporting quarter</span></div>
        {data.outcomes.map((o) => (
          <div key={o.name} style={{ display: 'grid', gridTemplateColumns: '1fr 90px 90px 110px 1fr', gap: 12, alignItems: 'center', padding: '10px 14px', borderBottom: '1px solid var(--line2)' }}>
            <div style={{ font: "400 12.5px/1.35 'Instrument Sans',sans-serif" }}>{o.name}</div>
            <div className="mono" style={{ fontSize: 12, color: 'var(--muted)' }}>{o.target_display}</div>
            <div className="mono" style={{ fontSize: 12, fontWeight: 500 }}>{o.actual_display ?? '—'}</div>
            <div><span className={`pill ${outcomeTone(o.status)}`}>{o.status.replace('_', ' ')}</span></div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span className="src-badge">{o.measure_source}</span>
              <span className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>{o.source_ref ?? ''}</span>
              {o.window_flag && (
                <span className="pill warn" title="Measurement window is shorter than the reporting period" style={{ marginLeft: 'auto' }}>
                  window {o.measured_days}d
                </span>
              )}
            </div>
          </div>
        ))}
      </div>

      <div className="grid-2">
        <div className="panel">
          <div className="panel-head">Clause &amp; obligation status</div>
          {data.clauses.map((c) => (
            <div key={c.clause_ref} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 14px', borderBottom: '1px solid var(--line2)' }}>
              <span className={`pill ${verdictTone(c.verdict)}`}>{c.verdict === 'cannot_evaluate' ? 'no data' : c.verdict}</span>
              <span className="mono" style={{ fontSize: 11, color: 'var(--muted)', width: 46, flex: 'none' }}>{c.clause_ref}</span>
              <span style={{ font: "400 12px/1.3 'Instrument Sans',sans-serif", flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.clause_name}</span>
              <span className={`src-badge`} title="how this verdict was produced">{c.method}</span>
              {c.money_note && <span className={`mono tone-${verdictTone(c.verdict)}`} style={{ fontSize: 11, fontWeight: 600 }}>{c.money_note}</span>}
            </div>
          ))}
        </div>
        <div className="panel">
          <div className="panel-head">Open risks &amp; recovery</div>
          {data.risks.length === 0 && <div style={{ padding: 14, font: "400 12px/1.5 'Instrument Sans',sans-serif", color: 'var(--faint)' }}>No open risks.</div>}
          {data.risks.map((r) => (
            <div key={r.risk_ref} style={{ padding: '9px 14px', borderBottom: '1px solid var(--line2)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className={`pill ${r.tone}`}>{r.severity}</span>
                <span style={{ font: "500 12px/1.3 'Instrument Sans',sans-serif", flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.title}</span>
              </div>
              <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 3 }}>{r.risk_ref} · {r.state} · {r.owner} {r.due_note ? `· ${r.due_note}` : ''}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
