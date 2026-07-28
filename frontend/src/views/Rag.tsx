import { useEffect, useState } from 'react'
import {
  api, bandLabel, bandTone, ago,
  type RagResponse, type RagMovementRow, type BubblingIncident,
} from '../api'

export default function Rag({ onOpenCustomer }: { onOpenCustomer: (id: string) => void }) {
  const [data, setData] = useState<RagResponse | null>(null)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    api.rag().then(setData).catch((e) => setErr(String(e)))
  }, [])

  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!data) return <div className="loading">diffing signal vs last snapshot…</div>

  const moved = data.movement.filter((m) => m.prev_band && m.health_band !== m.prev_band)

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow">
            vs snapshot {data.movement[0]?.snapshot_date?.slice(0, 10) ?? '—'} ·{' '}
            {moved.length} band change{moved.length === 1 ? '' : 's'} this week
          </div>
          <div className="page-title">RAG board</div>
        </div>
      </div>

      <div className="panel" style={{ marginBottom: 10 }}>
        <div className="panel-head">
          Movement — what changed since we last talked about each customer
        </div>
        {data.movement.map((m) => (
          <MovementRow key={m.customer_id} m={m} onClick={() => onOpenCustomer(m.customer_id)} />
        ))}
      </div>

      <div className="panel">
        <div className="panel-head">
          Bubbling up — incidents trending toward severe
          <span className="panel-note">score = comments + 6×reopens + 2×participants + cross-customer + priority</span>
        </div>
        {data.bubbling.map((b) => (
          <BubblingRow key={b.source_key} b={b} max={data.bubbling[0]?.bubble_score ?? 1} onClick={() => onOpenCustomer(b.customer_id)} />
        ))}
      </div>
    </div>
  )
}

function Delta({ label, value, invert = false, suffix = '' }: { label: string; value: number | null; invert?: boolean; suffix?: string }) {
  if (value == null || value === 0) return null
  const bad = invert ? value < 0 : value > 0
  return (
    <span className={`pill ${bad ? 'crit' : 'good'}`} style={{ textTransform: 'none', letterSpacing: 0, fontWeight: 500 }}>
      {label} {value > 0 ? '+' : ''}{Math.round(value * 10) / 10}{suffix}
    </span>
  )
}

function MovementRow({ m, onClick }: { m: RagMovementRow; onClick: () => void }) {
  const tone = bandTone(m.health_band)
  const changed = m.prev_band && m.prev_band !== m.health_band
  return (
    <div style={{ display: 'flex', gap: 14, padding: '12px 14px', borderBottom: '1px solid var(--line2)', alignItems: 'flex-start' }}>
      <button onClick={onClick} style={{ all: 'unset', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 10, width: 250, flex: 'none' }}>
        <span className={`mark ${tone}`} style={{ width: 30, height: 30 }}>{m.mark}</span>
        <span>
          <span style={{ display: 'block', font: "600 13px/1.3 'Instrument Sans',sans-serif", color: 'var(--ink)' }}>{m.name}</span>
          <span className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>{m.sector}</span>
        </span>
      </button>

      <div style={{ width: 180, flex: 'none', display: 'flex', alignItems: 'center', gap: 7 }}>
        {m.prev_band && <span className={`pill ${changed ? 'muted' : bandTone(m.prev_band)}`}>{bandLabel(m.prev_band)}</span>}
        <span className="mono" style={{ fontSize: 11, color: 'var(--faint)' }}>→</span>
        <span className={`pill ${tone}`}>{bandLabel(m.health_band)}</span>
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: m.topics.length ? 7 : 0 }}>
          <Delta label="breaches" value={m.breaches_delta} />
          <Delta label="clauses at risk" value={m.at_risk_delta} />
          <Delta label="outcomes" value={m.outcomes_delta} invert />
          <Delta label="open risks" value={m.risks_delta} />
          <Delta label="util" value={m.util_delta} suffix="pt" />
          {!changed && m.breaches_delta === 0 && m.at_risk_delta === 0 && m.outcomes_delta === 0 &&
            m.risks_delta === 0 && (m.util_delta == null || Math.abs(m.util_delta) < 0.5) && (
              <span className="mono" style={{ fontSize: 10.5, color: 'var(--faint)' }}>no material change</span>
            )}
        </div>
        {m.topics.slice(0, 2).map((t) => (
          <div key={t.risk_ref} style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 3 }}>
            <span className={`mono tone-${t.tone}`} style={{ fontSize: 9.5, fontWeight: 600 }}>{t.risk_ref}</span>
            <span style={{ font: "400 11.5px/1.35 'Instrument Sans',sans-serif", color: 'var(--ink2)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {t.title}
            </span>
            {t.due_note && <span className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', flex: 'none' }}>{t.due_note}</span>}
          </div>
        ))}
      </div>

      <div className="mono" style={{ width: 90, flex: 'none', textAlign: 'right', fontSize: 11, color: 'var(--muted)' }}>
        {m.outcomes_on_track}/{m.outcomes_total} outcomes
        <div style={{ color: 'var(--faint)', fontSize: 10, marginTop: 3 }}>{m.open_risks} open risks</div>
      </div>
    </div>
  )
}

function BubblingRow({ b, max, onClick }: { b: BubblingIncident; max: number; onClick: () => void }) {
  const tone = b.bubble_score >= max * 0.75 ? 'crit' : b.bubble_score >= max * 0.4 ? 'warn' : 'muted'
  const reasons: string[] = []
  if (b.comment_count >= 10) reasons.push(`${b.comment_count} comments`)
  if (b.reopen_count > 0) reasons.push(`reopened ×${b.reopen_count}`)
  if (b.participant_count >= 5) reasons.push(`${b.participant_count} people involved`)
  if (b.customers_sharing > 1) reasons.push(`same fingerprint at ${b.customers_sharing} customers`)
  if (b.priority === 'high') reasons.push('high priority')
  return (
    <div style={{ display: 'flex', gap: 12, padding: '11px 14px', borderBottom: '1px solid var(--line2)', alignItems: 'center' }}>
      <button onClick={onClick} style={{ all: 'unset', cursor: 'pointer' }}>
        <span className={`mark ${tone === 'muted' ? 'good' : tone}`} style={{ width: 26, height: 26, fontSize: 9.5 }}>{b.mark}</span>
      </button>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <span className="mono" style={{ fontSize: 10.5, fontWeight: 500, color: 'var(--muted)' }}>{b.source_key}</span>
          <span style={{ font: "500 12.5px/1.3 'Instrument Sans',sans-serif", whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{b.summary}</span>
        </div>
        <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 3 }}>
          {b.customer_name} · {b.status.replace('_', ' ')} · {reasons.join(' · ') || 'low churn'}
          {b.last_activity_at ? ` · active ${ago(b.last_activity_at)} ago` : ''}
        </div>
      </div>
      <div style={{ width: 130, flex: 'none' }}>
        <div className="bar-track" style={{ height: 5 }}>
          <div className="bar-fill" style={{ width: `${Math.round((b.bubble_score / max) * 100)}%`, background: `var(--${tone === 'muted' ? 'track' : tone})` }} />
        </div>
      </div>
      <span className={`mono tone-${tone}`} style={{ width: 34, flex: 'none', textAlign: 'right', fontSize: 12.5, fontWeight: 600 }}>
        {Math.round(b.bubble_score)}
      </span>
    </div>
  )
}
