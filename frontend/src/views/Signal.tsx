import { useEffect, useState } from 'react'
import {
  api, bandLabel, bandTone, money, shortDate,
  type SignalResponse, type SignalCustomer,
} from '../api'

export default function Signal({ onOpenCustomer }: { onOpenCustomer: (id: string) => void }) {
  const [data, setData] = useState<SignalResponse | null>(null)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    api.signal().then(setData).catch((e) => setErr(String(e)))
  }, [])

  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!data) return <div className="loading">querying semantic layer…</div>

  const k = data.kpis
  const outcomePct =
    k.outcomes_total ? Math.round((100 * (k.outcomes_on_track ?? 0)) / k.outcomes_total) : null
  const exposurePct =
    k.total_acv_pennies && k.exposure_pennies
      ? Math.round((100 * k.exposure_pennies) / k.total_acv_pennies)
      : null

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <div className="eyebrow">
            Portfolio · {k.engagements} active engagements · {money(k.total_acv_pennies)} ACV
          </div>
          <div className="page-title">Customer signal</div>
        </div>
        <button className="btn-primary">+ RAISE RISK</button>
      </div>

      <div className="kpi-grid">
        <Kpi label="Total ACV" value={money(k.total_acv_pennies)} sub={`${k.engagements} engagements`} />
        <Kpi
          label="Outcomes on track"
          value={`${k.outcomes_on_track ?? 0}/${k.outcomes_total ?? 0}`}
          unit={outcomePct != null ? `${outcomePct}%` : ''}
          tone={outcomePct != null && outcomePct < 70 ? 'warn' : 'ink'}
          sub="latest measurement vs target"
        />
        <Kpi
          label="Clause breaches"
          value={String(k.clause_breaches ?? 0)}
          unit="live"
          tone="crit"
          sub={`${k.clauses_at_risk ?? 0} more at risk`}
        />
        <Kpi
          label="Exposure at risk"
          value={money(k.exposure_pennies)}
          unit={exposurePct != null ? `${exposurePct}%` : ''}
          tone="crit"
          sub="of total ACV"
        />
        <Kpi
          label="Capacity gap"
          value={k.capacity_gap_fte != null ? k.capacity_gap_fte.toFixed(1) : '—'}
          unit="FTE"
          tone="warn"
          sub="planned minus assigned"
        />
        <Kpi
          label="Renewals ≤ 90d"
          value={String(k.renewals_90d ?? 0)}
          sub="inside the motion window"
        />
      </div>

      <div className="panel">
        <div className="sig-header">
          <div>Client</div><div>Health</div><div>Outcomes</div><div>Clauses</div>
          <div>Capacity</div><div>Velocity</div><div>Vehicle · renewal</div><div>Risks</div>
          <div style={{ textAlign: 'right' }}>ACV</div>
        </div>
        {data.customers.map((c) => (
          <Row key={c.customer_id} c={c} onClick={() => onOpenCustomer(c.customer_id)} />
        ))}
      </div>

      <div className="two-col">
        <div className="panel">
          <div className="panel-head">
            Needs a decision today <span className="panel-note">ranked by exposure</span>
          </div>
          {data.decisions.map((d) => (
            <div
              key={d.risk_ref}
              style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', borderBottom: '1px solid var(--line2)' }}
            >
              <span className={`pill ${d.tone}`}>{d.severity}</span>
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ font: "500 12.5px/1.35 'Instrument Sans',sans-serif", whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {d.title}
                </div>
                <div className="mono" style={{ fontSize: 10.5, color: 'var(--faint)', marginTop: 3 }}>
                  {d.scope_label} · {d.owner} · {d.due_note ?? ''}
                </div>
              </div>
              <div className="mono" style={{ fontSize: 11.5, fontWeight: 500, color: 'var(--ink2)' }}>
                {money(d.exposure_pennies)}
              </div>
              <button className="btn-ghost" style={{ height: 26, fontSize: 10 }}>{d.action_label}</button>
            </div>
          ))}
        </div>

        <div className="panel">
          <div className="panel-head">Renewal runway · next 180 days</div>
          <div style={{ padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 12 }}>
            {data.renewals.map((r) => {
              const tone = r.renewal_days <= 45 ? 'crit' : r.renewal_days <= 110 ? 'warn' : 'good'
              return (
                <div key={r.customer_id}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 5 }}>
                    <span style={{ font: "500 12px/1 'Instrument Sans',sans-serif" }}>{r.name}</span>
                    <span className={`mono tone-${tone}`} style={{ fontSize: 9.5, fontWeight: 600 }}>
                      {r.renewal_days} d
                    </span>
                    <span className="mono" style={{ marginLeft: 'auto', fontSize: 11.5, fontWeight: 500, color: 'var(--ink2)' }}>
                      {money(r.acv_pennies)}
                    </span>
                  </div>
                  <div className="bar-track">
                    <div
                      className="bar-fill"
                      style={{ width: `${Math.min(100, Math.round((r.renewal_days / 180) * 100))}%`, background: `var(--${tone})` }}
                    />
                  </div>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 4 }}>
                    {r.opportunity_open === false ? 'No renewal motion open · ' : ''}
                    {r.note ?? ''}
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}

function Kpi({ label, value, unit, sub, tone = 'ink' }: { label: string; value: string; unit?: string; sub?: string; tone?: string }) {
  return (
    <div className="kpi">
      <div className="kpi-label">{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline' }}>
        <span className={`kpi-value tone-${tone}`}>{value}</span>
        {unit ? <span className="kpi-unit">{unit}</span> : null}
      </div>
      {sub ? <div className="kpi-sub">{sub}</div> : null}
    </div>
  )
}

function Row({ c, onClick }: { c: SignalCustomer; onClick: () => void }) {
  const tone = bandTone(c.health_band)
  const outPct = c.outcomes_total ? Math.round((100 * c.outcomes_on_track) / c.outcomes_total) : 0
  const outTone = outPct >= 90 ? 'good' : outPct >= 55 ? 'warn' : 'crit'
  const utilTone =
    c.utilisation_pct == null ? 'muted'
    : c.utilisation_pct > 105 ? 'crit'
    : c.utilisation_pct > 100 || c.utilisation_pct < 75 ? 'warn'
    : 'good'
  const velTone =
    c.velocity_delta_pct == null ? 'muted'
    : c.velocity_delta_pct <= -15 ? 'crit'
    : c.velocity_delta_pct < 0 ? 'warn'
    : 'good'
  const renewTone =
    c.renewal_days == null ? 'muted' : c.renewal_days <= 45 ? 'crit' : c.renewal_days <= 110 ? 'warn' : 'muted'
  const clauseText =
    c.clause_breaches > 0
      ? `${c.clause_breaches} breach`
      : c.clauses_at_risk > 0
        ? `${c.clauses_at_risk} at risk`
        : 'clear'
  const clauseTone = c.clause_breaches > 0 ? 'crit' : c.clauses_at_risk > 0 ? 'warn' : 'good'
  const sparkMax = Math.max(...c.velocity_spark, 1)

  return (
    <button className="sig-row" onClick={onClick}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 11, minWidth: 0 }}>
        <div className={`mark ${tone}`} style={{ width: 30, height: 30 }}>{c.mark}</div>
        <div style={{ minWidth: 0 }}>
          <div style={{ font: "600 13.5px/1.3 'Instrument Sans',sans-serif", color: 'var(--ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {c.name}
          </div>
          <div className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>{c.sector}</div>
        </div>
      </div>
      <div><span className={`pill ${tone}`}>{bandLabel(c.health_band)}</span></div>
      <div>
        <div className="mono" style={{ fontSize: 12.5, fontWeight: 500, color: 'var(--ink2)', marginBottom: 6 }}>
          {c.outcomes_on_track}/{c.outcomes_total}
        </div>
        <div className="bar-track" style={{ width: 70, height: 3 }}>
          <div className="bar-fill" style={{ width: `${outPct}%`, background: `var(--${outTone})` }} />
        </div>
      </div>
      <div>
        <span className={`mono tone-${clauseTone}`} style={{ fontSize: 10, fontWeight: 500 }}>{clauseText}</span>
        <div className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', marginTop: 3 }}>{c.clauses_total} monitored</div>
      </div>
      <div>
        <div className={`mono tone-${utilTone}`} style={{ fontSize: 13, fontWeight: 500, marginBottom: 4 }}>
          {c.utilisation_pct != null ? `${c.utilisation_pct}%` : '—'}
        </div>
        <div className="mono" style={{ fontSize: 9.5, color: 'var(--faint)' }}>
          {c.margin_pct != null ? `margin ${c.margin_pct}%` : ''}
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
        <span className={`mono tone-${velTone}`} style={{ fontSize: 11.5, fontWeight: 500, width: 38, flex: 'none' }}>
          {c.velocity_delta_pct != null ? `${c.velocity_delta_pct > 0 ? '+' : ''}${c.velocity_delta_pct}%` : '—'}
        </span>
        <div className="spark">
          {c.velocity_spark.map((v, i) => (
            <span key={i} style={{ height: `${(v / sparkMax) * 19}px`, background: `var(--${velTone === 'muted' ? 'track' : velTone})`, opacity: 0.35 + i * 0.09 }} />
          ))}
        </div>
      </div>
      <div style={{ minWidth: 0 }}>
        <div style={{ font: "400 11.5px/1.35 'Instrument Sans',sans-serif", color: 'var(--ink2)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 152 }}>
          {c.vehicle_label ?? '—'}
        </div>
        <div className={`mono tone-${renewTone}`} style={{ fontSize: 10, fontWeight: 500, marginTop: 4 }}>
          {c.renewal_date ? `Renews ${shortDate(c.renewal_date)}` : 'Rolling'}
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span className="mono" style={{ fontSize: 14, fontWeight: 500, color: 'var(--ink2)' }}>{c.open_risks}</span>
        {c.crit_risks > 0 && (
          <span className="mono tone-crit" style={{ fontSize: 9.5, fontWeight: 600 }}>{c.crit_risks} crit</span>
        )}
      </div>
      <div style={{ textAlign: 'right' }}>
        <div className="mono" style={{ fontSize: 13.5, fontWeight: 500, color: 'var(--ink)' }}>{money(c.acv_pennies)}</div>
        <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 4 }}>{c.delta_label ?? ''}</div>
      </div>
    </button>
  )
}
