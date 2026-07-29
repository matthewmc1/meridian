import { useEffect, useState } from 'react'
import { api, shortDate, type JournalEntry } from '../api'

const NEXT_STATES = ['Watch', 'Breach', 'Escalated', 'Closed']

export default function Journal() {
  const [entries, setEntries] = useState<JournalEntry[] | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [filter, setFilter] = useState<'all' | 'crit' | 'open'>('all')
  const [nonce, setNonce] = useState(0)

  useEffect(() => {
    api.journal().then((d) => setEntries(d.entries)).catch((e) => setErr(String(e)))
  }, [nonce])

  const move = async (journalId: string, toState: string) => {
    await api.moveRisk({ journal_id: journalId, to_state: toState, note: `Moved to ${toState}`, actor: 'P. Raman' })
    setNonce((n) => n + 1)
  }

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
              <div className="foot-heading" style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Movement log</span>
                <span style={{ color: j.origin === 'manual' ? 'var(--accent)' : 'var(--faint)' }}>{j.origin}</span>
              </div>
              {j.movements.length > 0 ? (
                <div style={{ margin: '4px 0 10px' }}>
                  {j.movements.map((m) => (
                    <div key={m.seq} style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                      <span className="mono" style={{ fontSize: 9, color: 'var(--faint)', width: 12 }}>{m.seq}</span>
                      <span className="mono" style={{ fontSize: 9.5, color: 'var(--muted)' }}>{m.from_state ?? '·'} → {m.to_state}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, margin: '6px 0 10px' }}>
                  <span className="pill muted">{j.movement_from}</span>
                  <span className="mono" style={{ fontSize: 11, color: 'var(--faint)' }}>→</span>
                  <span className={`pill ${j.tone}`}>{j.movement_to}</span>
                </div>
              )}
              <div className="mono" style={{ fontSize: 10.5, color: 'var(--muted)', lineHeight: 1.5 }}>Owner {j.owner}</div>
              {j.due_note && <div className="mono" style={{ fontSize: 10.5, color: 'var(--faint)', lineHeight: 1.5 }}>{j.due_note}</div>}
              {j.state !== 'closed' && (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 8 }}>
                  {NEXT_STATES.filter((st) => st !== j.movement_to).map((st) => (
                    <button key={st} onClick={() => move(j.id, st)}
                      style={{ height: 20, padding: '0 6px', borderRadius: 3, border: '1px solid var(--line)', background: 'var(--surface)', color: 'var(--muted)', font: "500 9px/1 'IBM Plex Mono',monospace", cursor: 'pointer' }}>
                      → {st}
                    </button>
                  ))}
                </div>
              )}
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
