import { useEffect, useState } from 'react'
import {
  api, bandLabel, bandTone, money, shortDate,
  type SignalResponse, type SignalCustomer, type Decision,
} from '../api'
import { useThr, DefTip } from '../defs'
import RaiseRiskModal from '../RaiseRiskModal'
import DecisionModal from '../DecisionModal'

export default function Signal({ onOpenCustomer }: { onOpenCustomer: (id: string) => void }) {
  const [data, setData] = useState<SignalResponse | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [raising, setRaising] = useState(false)
  const [deciding, setDeciding] = useState<Decision | null>(null)
  const [nonce, setNonce] = useState(0)
  const thr = useThr()

  useEffect(() => {
    api.signal().then(setData).catch((e) => setErr(String(e)))
  }, [nonce])

  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!data) return <div className="loading">querying semantic layer…</div>

  const k = data.kpis
  const outcomePct = k.outcomes_total ? Math.round((100 * (k.outcomes_on_track ?? 0)) / k.outcomes_total) : null
  const coverageComplete = k.engagements_with_assignments === k.engagements_total

  return (
    <div className="page">
      {raising && (
        <RaiseRiskModal customers={data.customers} onClose={() => setRaising(false)}
          onDone={() => { setRaising(false); setNonce((n) => n + 1) }} />
      )}
      {deciding && (
        <DecisionModal journalId={deciding.journal_id} riskRef={deciding.risk_ref} title={deciding.title}
          onClose={() => setDeciding(null)} onDone={() => { setDeciding(null); setNonce((n) => n + 1) }} />
      )}

      <div className="page-head">
        <div>
          <div className="eyebrow">
            Portfolio · {k.engagements} active engagements · {money(k.total_acv_pennies)} ACV
          </div>
          <div className="page-title">Customer signal</div>
        </div>
        <button className="btn-primary" onClick={() => setRaising(true)}>+ RAISE RISK</button>
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
          label={<>Contractual exposure<DefTip k="exposure" /></>}
          value={money(k.remedy_pennies)}
          unit={k.any_uncapped ? '+ uncapped' : ''}
          tone={(k.remedy_pennies ?? 0) > 0 || k.any_uncapped ? 'crit' : 'ink'}
          sub="remedies on live breaches"
        />
        <Kpi
          label="ACV under watch"
          value={money(k.acv_under_watch_pennies)}
          tone={(k.acv_under_watch_pennies ?? 0) > 0 ? 'warn' : 'ink'}
          sub="context, not a loss estimate"
        />
        <Kpi
          label="Capacity gap"
          value={k.capacity_gap_fte != null ? k.capacity_gap_fte.toFixed(1) : '—'}
          unit="FTE"
          tone={(k.capacity_gap_fte ?? 0) > 0 ? 'warn' : 'ink'}
          sub={coverageComplete ? 'all engagements reporting'
            : `only ${k.engagements_with_assignments}/${k.engagements_total} engagements reporting`}
        />
        <Kpi
          label="Gates at risk ≤30d"
          value={String(k.gates_at_risk ?? 0)}
          tone={(k.gates_at_risk ?? 0) > 0 ? 'crit' : 'ink'}
          sub="evidence not yet verified"
        />
      </div>

      <div className="panel">
        <div className="sig-header">
          <div>Client · CSM</div><div>Health</div><div>Outcomes</div><div>Clauses</div>
          <div>Capacity</div><div>Velocity</div><div>Vehicle · renewal</div><div>Voice</div>
          <div style={{ textAlign: 'right' }}>ACV</div>
        </div>
        {data.customers.map((c) => (
          <Row key={c.customer_id} c={c} thr={thr} onClick={() => onOpenCustomer(c.customer_id)} />
        ))}
      </div>

      <div className="two-col">
        <div className="panel">
          <div className="panel-head">
            Needs a decision today <span className="panel-note">sorted by deadline · overdue first</span>
          </div>
          {data.decisions.map((d) => (
            <div key={d.risk_ref}
              style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', borderBottom: '1px solid var(--line2)' }}>
              <span className={`pill ${d.tone}`}>{d.severity}</span>
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ font: "500 12.5px/1.35 'Instrument Sans',sans-serif", whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {d.title}
                </div>
                <div className="mono" style={{ fontSize: 10.5, color: 'var(--faint)', marginTop: 3, display: 'flex', gap: 6, alignItems: 'center' }}>
                  {d.overdue && <span className="pill crit" style={{ height: 15 }}>OVERDUE</span>}
                  <span>{d.scope_label} · {d.owner}</span>
                  {d.due_at && <span className={d.overdue ? 'tone-crit' : ''}>· due {shortDate(d.due_at)}</span>}
                </div>
              </div>
              {d.exposure_pennies != null && (
                <div className="mono" style={{ fontSize: 11.5, fontWeight: 500, color: 'var(--ink2)' }}>{money(d.exposure_pennies)}</div>
              )}
              <button className="btn-ghost" style={{ height: 26, fontSize: 10 }} onClick={() => setDeciding(d)}>{d.action_label}</button>
            </div>
          ))}
        </div>

        <div className="panel">
          <div className="panel-head">
            Renewal runway · next 180 days <span className="panel-note">decision window = renewal − notice</span>
          </div>
          <div style={{ padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 12 }}>
            {data.renewals.map((r) => {
              const dwin = r.decision_days ?? r.renewal_days
              const tone = dwin <= 45 ? 'crit' : dwin <= 110 ? 'warn' : 'good'
              return (
                <div key={r.customer_id}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 5 }}>
                    <span style={{ font: "500 12px/1 'Instrument Sans',sans-serif" }}>{r.name}</span>
                    <span className={`mono tone-${tone}`} style={{ fontSize: 9.5, fontWeight: 600 }}>
                      {dwin}d to decide
                    </span>
                    <span className="mono" style={{ marginLeft: 'auto', fontSize: 11.5, fontWeight: 500, color: 'var(--ink2)' }}>
                      {money(r.acv_pennies)}
                    </span>
                  </div>
                  <div className="bar-track">
                    <div className="bar-fill" style={{ width: `${Math.max(0, Math.min(100, Math.round((dwin / 180) * 100)))}%`, background: `var(--${tone})` }} />
                  </div>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 4 }}>
                    {r.opportunity_open === false ? 'No renewal motion open · ' : ''}
                    renews {r.renewal_days}d · {r.notice_days ?? 0}d notice · {r.note ?? ''}
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

function Kpi({ label, value, unit, sub, tone = 'ink' }: { label: React.ReactNode; value: string; unit?: string; sub?: string; tone?: string }) {
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

function Row({ c, thr, onClick }: { c: SignalCustomer; thr: (k: string, n: string, f: number) => number; onClick: () => void }) {
  const tone = bandTone(c.health_band)
  const outPct = c.outcomes_total ? Math.round((100 * c.outcomes_on_track) / c.outcomes_total) : 0
  const outTone = outPct >= 90 ? 'good' : outPct >= 55 ? 'warn' : 'crit'
  const utilCrit = thr('utilisation', 'crit', 105), utilOver = thr('utilisation', 'over', 100), utilUnder = thr('utilisation', 'under', 75)
  const utilTone =
    c.utilisation_pct == null ? 'muted'
    : c.utilisation_pct > utilCrit ? 'crit'
    : c.utilisation_pct > utilOver || c.utilisation_pct < utilUnder ? 'warn'
    : 'good'
  const velCrit = thr('velocity', 'crit_pct', -15)
  const velTone =
    c.velocity_delta_pct == null ? 'muted'
    : c.velocity_delta_pct <= velCrit ? 'crit'
    : c.velocity_delta_pct < 0 ? 'warn'
    : 'good'
  const renewCrit = thr('renewal_runway', 'crit_days', 45), renewWarn = thr('renewal_runway', 'warn_days', 110)
  const decideDays = c.renewal_days != null ? c.renewal_days - (c.notice_days ?? 0) : null
  const renewTone = decideDays == null ? 'muted' : decideDays <= renewCrit ? 'crit' : decideDays <= renewWarn ? 'warn' : 'muted'
  const clauseText =
    c.clause_breaches > 0 ? `${c.clause_breaches} breach`
    : c.clauses_at_risk > 0 ? `${c.clauses_at_risk} at risk`
    : c.clauses_cannot_eval > 0 ? `${c.clauses_cannot_eval} no data`
    : 'clear'
  const clauseTone = c.clause_breaches > 0 ? 'crit' : c.clauses_at_risk > 0 || c.clauses_cannot_eval > 0 ? 'warn' : 'good'
  const sparkMax = Math.max(...c.velocity_spark, 1)
  const csatTone = c.csat_delta == null ? 'muted' : c.csat_delta <= -0.5 ? 'crit' : c.csat_delta < 0 ? 'warn' : 'good'

  return (
    <button className="sig-row" onClick={onClick}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 11, minWidth: 0 }}>
        <div className={`mark ${tone}`} style={{ width: 30, height: 30 }}>{c.mark}</div>
        <div style={{ minWidth: 0 }}>
          <div style={{ font: "600 13.5px/1.3 'Instrument Sans',sans-serif", color: 'var(--ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {c.name}
          </div>
          <div className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>{c.csm_name ?? c.sector}</div>
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
          {c.utilisation_pct != null ? `${c.utilisation_pct}%` : 'no data'}
        </div>
        <div className="mono" style={{ fontSize: 9.5, color: c.margin_pct == null ? 'var(--warn)' : 'var(--faint)' }}>
          {c.util_weeks_over_100 >= 4 ? `${c.util_weeks_over_100}w streak`
            : c.margin_pct != null ? `margin ${c.margin_pct}%`
            : 'margin: no data'}
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
      <div>
        {c.csat_latest != null ? (
          <>
            <div className={`mono tone-${csatTone}`} style={{ fontSize: 12.5, fontWeight: 500 }}>
              {c.csat_latest.toFixed(1)}{c.csat_delta != null && c.csat_delta !== 0 ? (c.csat_delta > 0 ? ' ↑' : ' ↓') : ''}
            </div>
            <div className="mono" style={{ fontSize: 9, color: c.sponsor_status === 'departing' || c.sponsor_status === 'departed' ? 'var(--crit)' : 'var(--faint)' }}>
              {c.sponsor_status === 'departing' ? 'sponsor leaving' : c.sponsor_status === 'new' ? 'new sponsor' : 'CSAT'}
            </div>
          </>
        ) : <span className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>no CSAT</span>}
      </div>
      <div style={{ textAlign: 'right' }}>
        <div className="mono" style={{ fontSize: 13.5, fontWeight: 500, color: 'var(--ink)' }}>{money(c.acv_pennies)}</div>
        <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginTop: 4 }}>{c.delta_label ?? ''}</div>
      </div>
    </button>
  )
}
