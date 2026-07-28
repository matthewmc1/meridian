import { useEffect, useState } from 'react'
import { api, shortDate, type JournalEntry } from '../api'

export default function Journal() {
  const [entries, setEntries] = useState<JournalEntry[] | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [filter, setFilter] = useState<'all' | 'crit' | 'open'>('all')

  useEffect(() => {
    api.journal().then((d) => setEntries(d.entries)).catch((e) => setErr(String(e)))
  }, [])

  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!entries) return <div className="loading">querying journal…</div>

  const shown = entries.filter((e) =>
    filter === 'all' ? true : filter === 'crit' ? e.tone === 'crit' : e.state !== 'closed',
  )
  const open = entries.filter((e) => e.state !== 'closed').length

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow">Immutable log · {open} open risks</div>
          <div className="page-title">Risk journal</div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          {([['all', 'All'], ['crit', 'Critical only'], ['open', 'Open only']] as const).map(([k, label]) => (
            <button key={k} className={filter === k ? 'btn-primary' : 'btn-ghost'} onClick={() => setFilter(k)}>
              {label}
            </button>
          ))}
        </div>
      </div>

      <div className="panel">
        {shown.map((j) => (
          <div key={j.id} style={{ display: 'flex', borderBottom: '1px solid var(--line2)' }}>
            <div style={{ width: 112, flex: 'none', padding: '14px 12px', borderRight: '1px solid var(--line2)', background: 'var(--surface2)' }}>
              <div className="mono" style={{ fontSize: 11, fontWeight: 500, color: 'var(--ink2)' }}>{shortDate(j.created_at)}</div>
              <div className={`mono tone-${j.tone}`} style={{ fontSize: 9.5, fontWeight: 500, marginTop: 9 }}>{j.risk_ref}</div>
            </div>
            <div style={{ flex: 1, minWidth: 0, padding: 14 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 7, flexWrap: 'wrap' }}>
                <span className={`pill ${j.tone}`}>{j.severity}</span>
                <span style={{ font: "600 13.5px/1.25 'Instrument Sans',sans-serif" }}>{j.title}</span>
                <span className="mono" style={{ fontSize: 11, color: 'var(--faint)' }}>{j.scope_label}</span>
              </div>
              <div style={{ font: "400 12.5px/1.55 'Instrument Sans',sans-serif", color: 'var(--muted)', maxWidth: 820, marginBottom: 9 }}>
                {j.body}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
                {j.links.map((l) => (
                  <span key={l.text} className={`pill ${l.tone}`} style={{ textTransform: 'none', letterSpacing: 0, fontWeight: 500 }}>
                    {l.text}
                  </span>
                ))}
              </div>
            </div>
            <div style={{ width: 214, flex: 'none', padding: 14, borderLeft: '1px solid var(--line2)' }}>
              <div className="foot-heading">Movement</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10 }}>
                <span className="pill muted">{j.movement_from}</span>
                <span className="mono" style={{ fontSize: 11, color: 'var(--faint)' }}>→</span>
                <span className={`pill ${j.tone}`}>{j.movement_to}</span>
              </div>
              <div className="mono" style={{ fontSize: 10.5, color: 'var(--muted)', lineHeight: 1.5 }}>Owner {j.owner}</div>
              {j.due_note && <div className="mono" style={{ fontSize: 10.5, color: 'var(--faint)', lineHeight: 1.5 }}>{j.due_note}</div>}
            </div>
          </div>
        ))}
        {shown.length === 0 && (
          <div style={{ padding: 20, font: "400 12px/1.5 'Instrument Sans',sans-serif", color: 'var(--faint)' }}>
            Nothing matches this filter.
          </div>
        )}
      </div>
    </div>
  )
}
