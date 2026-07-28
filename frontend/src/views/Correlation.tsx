import { useEffect, useMemo, useState } from 'react'
import { api, money, shortDate, type CorrelationResponse } from '../api'

const IMPACT: Record<string, { label: string; tone: string }> = {
  impacted: { label: 'Impacted', tone: 'crit' },
  potentially_impacted: { label: 'Potential', tone: 'warn' },
  not_vulnerable: { label: 'Clear', tone: 'good' },
}

const CELL: Record<string, string> = {
  vulnerable: 'var(--crit)',
  drift: 'var(--warn)',
  patched: 'var(--good)',
  none: 'var(--track)',
}

export default function Correlation({ onOpenCustomer }: { onOpenCustomer: (id: string) => void }) {
  const [data, setData] = useState<CorrelationResponse | null>(null)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    api.correlation().then(setData).catch((e) => setErr(String(e)))
  }, [])

  const grid = useMemo(() => {
    if (!data) return { services: [] as string[], marks: [] as string[], cell: new Map<string, string>() }
    const services = [...new Set(data.matrix.map((m) => m.service))]
    const marks = [...new Set(data.matrix.map((m) => m.mark))]
    const cell = new Map(data.matrix.map((m) => [`${m.service}|${m.mark}`, m.status]))
    return { services, marks, cell }
  }, [data])

  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!data) return <div className="loading">querying correlation graph…</div>
  if (!data.vulnerability)
    return <div className="loading">No active vulnerability clusters — the service inventory is clear.</div>

  const v = data.vulnerability
  const impacted = data.affected.filter((a) => a.impact === 'impacted')
  const potential = data.affected.filter((a) => a.impact === 'potentially_impacted')
  const exposed = [...impacted, ...potential].reduce((s, a) => s + (a.acv_pennies ?? 0), 0)
  const clausesEngaged = data.affected.filter((a) => a.security_clause_ref).length

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow crit">Active cluster · disclosed {shortDate(v.disclosed_at)}</div>
          <div className="page-title">{v.ref} · {v.service_name}</div>
          {v.description && (
            <div style={{ font: "400 12.5px/1.5 'Instrument Sans',sans-serif", color: 'var(--muted)', marginTop: 7, maxWidth: 760 }}>
              {v.description}
            </div>
          )}
        </div>
        <button className="btn-primary">RAISE CROSS-CUSTOMER RISK · {impacted.length + potential.length}</button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 9, marginBottom: 14 }}>
        <Kpi label="Customers impacted" value={String(impacted.length)} sub={impacted.map((a) => a.customer_name).join(' · ') || '—'} tone="crit" />
        <Kpi label="Potentially impacted" value={String(potential.length)} sub={potential.map((a) => a.customer_name).join(' · ') || '—'} tone="warn" />
        <Kpi label="ACV exposed" value={money(exposed)} sub="impacted + potential" tone="crit" />
        <Kpi label="Clauses engaged" value={String(clausesEngaged)} sub="security remediation obligations" tone="warn" />
      </div>

      <div className="panel" style={{ marginBottom: 10 }}>
        <div className="panel-head">Blast radius · contractual, not just technical</div>
        <div className="sig-header" style={{ gridTemplateColumns: '196px 104px 128px 1fr 150px 118px' }}>
          <div>Client</div><div>Version</div><div>Impact</div><div>Clause at stake</div><div>Environment</div>
          <div style={{ textAlign: 'right' }}>ACV</div>
        </div>
        {data.affected.map((a) => {
          const imp = IMPACT[a.impact]
          return (
            <button key={a.customer_id + a.version} className="sig-row"
              style={{ gridTemplateColumns: '196px 104px 128px 1fr 150px 118px', minHeight: 58 }}
              onClick={() => onOpenCustomer(a.customer_id)}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                <span className={`mark ${imp.tone === 'good' ? 'good' : imp.tone === 'warn' ? 'warn' : 'crit'}`} style={{ width: 26, height: 26, fontSize: 9.5 }}>{a.mark}</span>
                <span style={{ font: "600 12.5px/1.25 'Instrument Sans',sans-serif" }}>{a.customer_name}</span>
              </div>
              <div className="mono" style={{ fontSize: 11, fontWeight: 500, color: 'var(--ink2)' }}>{a.version}</div>
              <div><span className={`pill ${imp.tone}`}>{imp.label}</span></div>
              <div style={{ minWidth: 0, paddingRight: 14 }}>
                <div style={{ font: "400 11.5px/1.35 'Instrument Sans',sans-serif", color: 'var(--ink2)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {a.security_clause_name ?? '—'}
                </div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 2 }}>
                  {a.security_clause_ref ?? ''} {a.remedy_type === 'uncapped_credit' ? '· uncapped credit' : ''}
                </div>
              </div>
              <div className="mono" style={{ fontSize: 11, color: 'var(--ink2)' }}>{a.env_label} · {a.exposure.replace('_', ' ')}</div>
              <div className="mono" style={{ textAlign: 'right', fontSize: 13, fontWeight: 500 }}>{money(a.acv_pennies)}</div>
            </button>
          )
        })}
      </div>

      <div className="panel" style={{ marginBottom: 10 }}>
        <div className="panel-head">
          Why we think each customer is impacted
          <span className="panel-note">every claim resolves to a source record</span>
        </div>
        <div style={{ padding: 14, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10 }}>
          {[...new Set(data.rationale.map((r) => r.customer_id))].map((cid) => {
            const rows = data.rationale.filter((r) => r.customer_id === cid)
            const who = data.affected.find((a) => a.customer_id === cid)
            return (
              <div key={cid} style={{ border: '1px solid var(--line)', borderRadius: 6, background: 'var(--surface2)', overflow: 'hidden' }}>
                <button onClick={() => onOpenCustomer(cid)}
                  style={{ all: 'unset', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, padding: '10px 12px', borderBottom: '1px solid var(--line2)', width: '100%', boxSizing: 'border-box' }}>
                  <span className={`mark ${who?.impact === 'impacted' ? 'crit' : 'warn'}`} style={{ width: 22, height: 22, fontSize: 9 }}>{who?.mark ?? '?'}</span>
                  <span style={{ font: "600 12.5px/1.2 'Instrument Sans',sans-serif" }}>{who?.customer_name ?? cid}</span>
                  <span className={`pill ${who?.impact === 'impacted' ? 'crit' : 'warn'}`} style={{ marginLeft: 'auto' }}>
                    {who?.impact === 'impacted' ? 'Impacted' : 'Potential'}
                  </span>
                </button>
                {rows.map((r, i) => (
                  <div key={i} style={{ padding: '9px 12px', borderBottom: '1px solid var(--line2)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                      <span className={`pill ${r.confidence === 'confirmed' ? 'good' : r.confidence === 'probable' ? 'warn' : 'muted'}`}>{r.confidence}</span>
                      <span className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', textTransform: 'uppercase' }}>{r.evidence_kind}</span>
                      {r.evidence_source && <span className="src-badge">{r.evidence_source}</span>}
                    </div>
                    <div style={{ font: "400 11.5px/1.45 'Instrument Sans',sans-serif", color: 'var(--ink2)' }}>{r.rationale}</div>
                    <div className="mono" style={{ fontSize: 10, marginTop: 4 }}>
                      {r.artifact_url
                        ? <a href={r.artifact_url} target="_blank" rel="noreferrer">{r.evidence_label}</a>
                        : <span style={{ color: 'var(--faint)' }}>{r.evidence_label}</span>}
                    </div>
                  </div>
                ))}
              </div>
            )
          })}
        </div>
      </div>

      <div className="two-col" style={{ gridTemplateColumns: '1fr 430px', marginTop: 0 }}>
        <div className="panel">
          <div className="panel-head">Shared service inventory — where else this pattern repeats</div>
          <div style={{ padding: '12px 14px' }}>
            <div style={{ display: 'grid', gridTemplateColumns: `172px repeat(${grid.marks.length},1fr)`, gap: 3, marginBottom: 4 }}>
              <div />
              {grid.marks.map((m) => (
                <div key={m} className="mono" style={{ fontSize: 9, color: 'var(--faint)', textAlign: 'center' }}>{m}</div>
              ))}
            </div>
            {grid.services.map((s) => (
              <div key={s} style={{ display: 'grid', gridTemplateColumns: `172px repeat(${grid.marks.length},1fr)`, gap: 3, marginBottom: 3, alignItems: 'center' }}>
                <div style={{ font: "400 11px/1.2 'Instrument Sans',sans-serif", color: 'var(--ink2)', paddingRight: 8, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s}</div>
                {grid.marks.map((m) => {
                  const status = grid.cell.get(`${s}|${m}`) ?? 'none'
                  return (
                    <div key={m} title={`${m} · ${status}`}
                      style={{ height: 24, borderRadius: 3, background: CELL[status], opacity: status === 'none' ? 0.5 : 0.85, display: 'grid', placeItems: 'center', font: "700 10px/1 'IBM Plex Mono',monospace", color: 'var(--surface)' }}>
                      {status === 'vulnerable' ? '!' : ''}
                    </div>
                  )
                })}
              </div>
            ))}
            <div className="mono" style={{ display: 'flex', gap: 14, marginTop: 12, paddingTop: 11, borderTop: '1px solid var(--line2)', fontSize: 10, color: 'var(--faint)' }}>
              <Legend color="var(--crit)" label="vulnerable" />
              <Legend color="var(--warn)" label="version drift" />
              <Legend color="var(--good)" label="patched" />
              <Legend color="var(--track)" label="not deployed" />
            </div>
          </div>
        </div>

        <div className="panel">
          <div className="panel-head">Correlated symptoms <span className="src-badge">jsm</span></div>
          {data.symptoms.map((s) => {
            const t = s.customers_sharing > 1 ? 'crit' : 'warn'
            return (
              <div key={s.source_key} style={{ padding: '10px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                <span style={{ width: 7, height: 7, borderRadius: '50%', background: `var(--${t})`, flex: 'none', marginTop: 5 }} />
                <div style={{ flex: 1 }}>
                  <div style={{ font: "400 12px/1.4 'Instrument Sans',sans-serif" }}>{s.summary}</div>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 3 }}>
                    {s.customer_name} · {s.source_key}
                    {s.fingerprint ? ` · ${s.fingerprint}` : ''}
                    {s.customers_sharing > 1 ? ` · shared by ${s.customers_sharing} customers` : ''}
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

function Kpi({ label, value, sub, tone }: { label: string; value: string; sub: string; tone: string }) {
  return (
    <div className="kpi">
      <div className="kpi-label">{label}</div>
      <div className={`kpi-value tone-${tone}`}>{value}</div>
      <div className="kpi-sub">{sub}</div>
    </div>
  )
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      <span style={{ width: 9, height: 9, borderRadius: 2, background: color }} />
      {label}
    </span>
  )
}
