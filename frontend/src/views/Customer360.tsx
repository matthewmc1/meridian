import { useEffect, useState } from 'react'
import {
  api, bandLabel, bandTone, money, shortDate, verdictTone, ago,
  type Customer360Response,
} from '../api'

export default function Customer360({
  customerId, onBack,
}: {
  customerId: string | null
  onBack: () => void
  onPick: (id: string) => void
}) {
  const [data, setData] = useState<Customer360Response | null>(null)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    if (!customerId) return
    setData(null)
    api.customer(customerId).then(setData).catch((e) => setErr(String(e)))
  }, [customerId])

  if (!customerId)
    return (
      <div className="loading">
        Pick a customer from the <button className="btn-ghost" onClick={onBack}>Customer signal</button> view.
      </div>
    )
  if (err) return <div className="error-box">Data layer unreachable: {err}</div>
  if (!data) return <div className="loading">querying semantic layer…</div>

  const h = data.header
  const tone = bandTone(h.health_band)

  return (
    <div>
      <div style={{ padding: '20px 22px 16px', borderBottom: '1px solid var(--line)', background: 'var(--surface)' }}>
        <div className="mono" style={{ display: 'flex', gap: 9, fontSize: 10.5, color: 'var(--faint)', marginBottom: 12 }}>
          <button className="banner-action" style={{ borderBottom: 'none' }} onClick={onBack}>Customers</button>
          <span>/</span><span>{h.name}</span><span>/</span><span>360</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 18 }}>
          <div className={`mark ${tone}`} style={{ width: 44, height: 44, fontSize: 15 }}>{h.mark}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 11, marginBottom: 6 }}>
              <h2 style={{ margin: 0, font: "600 24px/1.05 'Instrument Sans',sans-serif", letterSpacing: '-0.022em' }}>{h.name}</h2>
              <span className={`pill ${tone}`}>{bandLabel(h.health_band)}</span>
              {h.clause_breaches > 0 && (
                <span className="pill muted">{h.clause_breaches} clause breach{h.clause_breaches > 1 ? 'es' : ''}</span>
              )}
            </div>
            <div className="mono" style={{ display: 'flex', gap: 22, fontSize: 11.5, color: 'var(--muted)', flexWrap: 'wrap' }}>
              <span>{h.sector}</span>
              <span>{h.instrument_ref}</span>
              {h.csm_name && <span>CSM {h.csm_name}</span>}
              {h.delivery_lead && <span>Delivery lead {h.delivery_lead}</span>}
              {h.renewal_date && <span>Renews {shortDate(h.renewal_date)}</span>}
            </div>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5,1fr)', gap: 9, marginTop: 16 }}>
          <Tile label="Contract value" src="salesforce" value={money(h.acv_pennies)} unit="ACV"
            sub={h.tcv_pennies ? `${money(h.tcv_pennies)} TCV` : '—'} />
          <Tile label="Milestone gates" src="jira"
            value={h.gates_total ? `${h.gates_passed}/${h.gates_total}` : '—'} unit="passed"
            tone={h.gates_total && h.gates_passed !== h.gates_total ? 'warn' : 'ink'}
            sub={h.gates_total && h.gates_passed !== h.gates_total ? 'gate evidence outstanding' : 'all gates verified'} />
          <Tile label="Outcome index" src="derived"
            value={h.outcome_index != null ? String(Math.round(h.outcome_index)) : '—'} unit="/100"
            tone={h.outcome_index != null && h.outcome_index < 75 ? 'warn' : 'ink'}
            sub="mean attainment across outcomes" />
          <Tile label="Capacity" src="workday"
            value={h.utilisation_pct != null ? `${h.utilisation_pct}%` : '—'} unit="util"
            tone={h.utilisation_pct != null && (h.utilisation_pct > 100 || h.utilisation_pct < 75) ? 'warn' : 'ink'}
            sub={h.planned_fte ? `${h.assigned_fte ?? 0} of ${h.planned_fte} FTE assigned` : '—'} />
          <Tile label="Margin" src="workday"
            value={h.margin_pct != null ? `${h.margin_pct}%` : '—'} unit="actual"
            tone={h.margin_pct != null && h.margin_pct < 15 ? 'crit' : 'ink'} sub="latest Workday period" />
        </div>
      </div>

      <div className="grid-2" style={{ padding: '16px 22px 40px' }}>
        <div className="panel">
          <div className="panel-head">
            Contracted outcomes
            <span className="panel-note">{h.outcomes_on_track} of {h.outcomes_total} met</span>
          </div>
          {data.outcomes.map((o) => {
            const t = o.status === 'met' ? 'good' : o.status === 'behind' ? 'warn' : o.status === 'at_risk' ? 'crit' : 'muted'
            return (
              <div key={o.name} style={{ padding: '11px 14px', borderBottom: '1px solid var(--line2)' }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 9, marginBottom: 7 }}>
                  <span style={{ width: 7, height: 7, borderRadius: '50%', background: `var(--${t})`, flex: 'none' }} />
                  <span style={{ font: "500 12.5px/1.3 'Instrument Sans',sans-serif", flex: 1 }}>{o.name}</span>
                  <span className="mono" style={{ fontSize: 11, fontWeight: 500, color: 'var(--ink2)' }}>{o.actual_display ?? '—'}</span>
                  <span className="mono" style={{ fontSize: 11, color: 'var(--faint)' }}>/ {o.target_display}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                  <div className="bar-track" style={{ flex: 1, height: 5 }}>
                    <div className="bar-fill" style={{ width: `${Math.round(o.attainment_pct)}%`, background: `var(--${t})` }} />
                  </div>
                  <span className={`pill ${t}`}>{o.status.replace('_', ' ')}</span>
                  <span className="src-badge">{o.measure_source}</span>
                </div>
              </div>
            )
          })}
        </div>

        <div className="panel">
          <div className="panel-head">
            Smart contract monitor
            <span className="panel-note">
              evaluated {ago(data.clauses[0]?.evaluated_at ?? null)} ago
            </span>
          </div>
          {data.clauses.map((c) => {
            const t = verdictTone(c.verdict)
            const label = c.verdict === 'breach' ? 'BREACH' : c.verdict === 'at_risk' ? 'AT RISK' : c.verdict === 'met' ? 'MET' : 'NO DATA'
            return (
              <div key={c.clause_ref} style={{ padding: '10px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', alignItems: 'flex-start', gap: 11 }}>
                <span className={`pill ${t}`} style={{ marginTop: 1 }}>{label}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                    <span className="mono" style={{ fontSize: 11, fontWeight: 500, color: 'var(--muted)' }}>{c.clause_ref}</span>
                    <span style={{ font: "500 12.5px/1.3 'Instrument Sans',sans-serif" }}>{c.clause_name}</span>
                  </div>
                  <div style={{ font: "400 11px/1.45 'Instrument Sans',sans-serif", color: 'var(--muted)', marginTop: 3 }}>{c.test_description}</div>
                  {c.evidence_note && (
                    <div style={{ marginTop: 6 }}>
                      <span className={`pill ${t}`} style={{ textTransform: 'none', letterSpacing: 0, fontWeight: 500 }}>{c.evidence_note}</span>
                    </div>
                  )}
                </div>
                {c.money_note && (
                  <div className={`mono tone-${t}`} style={{ fontSize: 11.5, fontWeight: 600, textAlign: 'right', width: 70, paddingTop: 2 }}>{c.money_note}</div>
                )}
              </div>
            )
          })}
        </div>

        <div className="panel">
          <div className="panel-head">
            Capacity → delivery outcomes <span className="src-badge">workday</span>
          </div>
          <div style={{ padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 9, borderBottom: '1px solid var(--line2)' }}>
            {data.team.length === 0 && <Empty note="No assignments ingested for this engagement yet." />}
            {data.team.map((p) => {
              const t = p.utilisation_pct > 105 ? 'crit' : p.utilisation_pct > 100 || p.utilisation_pct < 75 ? 'warn' : 'good'
              return (
                <div key={p.role} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ font: "400 11.5px/1 'Instrument Sans',sans-serif", color: 'var(--ink2)', width: 150, flex: 'none', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.role}</span>
                  <div className="bar-track" style={{ flex: 1, height: 16 }}>
                    <div className="bar-fill" style={{ width: `${Math.min(p.utilisation_pct, 100)}%`, background: `var(--${t})`, opacity: 0.75 }} />
                  </div>
                  <span className={`mono tone-${t}`} style={{ fontSize: 11, fontWeight: 500, width: 40, textAlign: 'right', flex: 'none' }}>{p.utilisation_pct}%</span>
                  <span className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', width: 132, flex: 'none', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}
                    title={p.delivery_outcome ?? ''}>
                    {p.delivery_outcome ? `→ ${p.delivery_outcome}` : ''}
                  </span>
                  {p.flag && <span className="pill crit">{p.flag}</span>}
                </div>
              )
            })}
          </div>
          <div style={{ padding: '10px 14px 12px' }}>
            <div className="foot-heading" style={{ marginBottom: 8 }}>Delivery outcomes this capacity is driving</div>
            {data.delivery_outcomes.map((d) => {
              const t = d.status === 'on_track' ? 'good' : d.status === 'done' ? 'good' : d.status === 'at_risk' ? 'warn' : 'crit'
              return (
                <div key={d.name} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 0' }}>
                  <span className={`pill ${t}`}>{d.status.replace('_', ' ')}</span>
                  <span style={{ font: "500 12px/1.3 'Instrument Sans',sans-serif", flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={d.description ?? ''}>
                    {d.name}
                  </span>
                  {d.committed_fte != null && (
                    <span className="mono" style={{ fontSize: 10, color: 'var(--muted)', flex: 'none' }}>{d.committed_fte} FTE</span>
                  )}
                  <span className="mono" style={{ fontSize: 9.5, color: 'var(--faint)', flex: 'none', maxWidth: 170, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {d.supports_contracted ? `supports: ${d.supports_contracted}` : 'operational'}
                  </span>
                </div>
              )
            })}
          </div>
        </div>

        <div className="panel">
          <div className="panel-head">Delivery evidence <span className="src-badge">jira</span></div>
          <div style={{ padding: '12px 14px 8px', display: 'flex', alignItems: 'flex-end', gap: 3, height: 74 }}>
            {data.velocity.map((v, i) => {
              const max = Math.max(...data.velocity.map((x) => x.value), 1)
              return (
                <div key={i} title={`${v.source_ref ?? ''} · ${v.value} pts`}
                  style={{ flex: 1, height: `${(v.value / max) * 100}%`, borderRadius: '2px 2px 0 0', background: i >= data.velocity.length - 3 ? 'var(--warn)' : 'var(--accent)', opacity: i >= data.velocity.length - 3 ? 0.9 : 0.55 }} />
              )
            })}
          </div>
          {data.epics.map((e) => {
            const bt = e.blocked_days == null ? 'muted' : e.blocked_days >= 7 ? 'crit' : 'warn'
            const st = e.state === 'gate' ? 'crit' : e.state === 'in_progress' ? 'warn' : e.state === 'done' ? 'good' : 'muted'
            return (
              <div key={e.source_key} style={{ padding: '9px 14px', borderTop: '1px solid var(--line2)', display: 'flex', alignItems: 'center', gap: 10 }}>
                <span className="mono" style={{ fontSize: 10.5, fontWeight: 500, color: 'var(--muted)', width: 66, flex: 'none' }}>{e.source_key}</span>
                <span style={{ font: "400 12px/1.3 'Instrument Sans',sans-serif", flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{e.title}</span>
                <span className={`mono tone-${bt}`} style={{ fontSize: 10.5, fontWeight: 500, width: 80, textAlign: 'right', flex: 'none' }}>
                  {e.blocked_days != null ? `${e.blocked_days} d blocked` : '—'}
                </span>
                <span className={`pill ${st}`}>{e.state.replace('_', ' ')}</span>
              </div>
            )
          })}
        </div>

        <div className="panel" style={{ gridColumn: '1 / -1' }}>
          <div className="panel-head">
            Evidence &amp; artifacts
            <span className="panel-note">missing artifacts fail gates automatically</span>
          </div>
          {data.evidence.length === 0 && <Empty note="No evidence requirements configured for this engagement yet." />}
          {data.evidence.map((ev) => {
            const t = ev.state === 'verified' ? 'good' : ev.state === 'missing' ? 'crit' : ev.state === 'stale' ? 'warn' : 'muted'
            return (
              <div key={ev.requirement + (ev.clause_ref ?? '')} style={{ padding: '10px 14px', borderBottom: '1px solid var(--line2)', display: 'flex', alignItems: 'center', gap: 12 }}>
                <span className={`pill ${t}`}>{ev.state}</span>
                <span className="mono" style={{ fontSize: 12, color: 'var(--ink2)', width: 190, flex: 'none' }}>{ev.requirement}</span>
                {ev.clause_ref && <span className="mono" style={{ fontSize: 10.5, color: 'var(--muted)' }}>gates {ev.clause_ref}</span>}
                <span style={{ flex: 1 }} />
                {ev.artifact_kind && <span className="src-badge">{ev.artifact_kind.replace('_', ' ')}</span>}
                {ev.pinned_version && <span className="mono" style={{ fontSize: 10, color: 'var(--faint)' }}>pinned {ev.pinned_version}</span>}
                <span className="mono" style={{ fontSize: 10.5, color: 'var(--faint)' }}>
                  {ev.state === 'verified' && ev.verified_at
                    ? `verified ${shortDate(ev.verified_at)} · ${ev.verified_by ?? ''}`
                    : ev.due_at ? `due ${shortDate(ev.due_at)}` : ''}
                </span>
              </div>
            )
          })}
        </div>
        <div className="panel" style={{ gridColumn: '1 / -1' }}>
          <div className="panel-head">
            Products &amp; telemetry
            <span className="panel-note">how the client actually uses what we shipped</span>
          </div>
          <div style={{ padding: 14, display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10 }}>
            {data.products.length === 0 && <Empty note="No products catalogued for this customer yet." />}
            {data.products.map((p) => (
              <div key={p.product_id} style={{ border: '1px solid var(--line)', borderRadius: 6, padding: '12px 13px', background: 'var(--surface2)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                  <span style={{ font: "600 13px/1.2 'Instrument Sans',sans-serif" }}>{p.name}</span>
                  <span className={`pill ${p.stage === 'ga' ? 'good' : p.stage === 'beta' ? 'warn' : 'muted'}`}>{p.stage}</span>
                </div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--faint)', marginBottom: 9 }}>
                  {p.kind.replace('_', ' ')}
                  {p.launched_at ? ` · launched ${shortDate(p.launched_at)}` : ''}
                  {p.depends_on ? ` · runs on ${p.depends_on}` : ''}
                </div>
                {p.telemetry.map((t) => {
                  const worse = t.baseline != null &&
                    (t.metric === 'uptime_pct' || t.metric === 'crash_free_pct' ? t.value < t.baseline : t.value > t.baseline)
                  return (
                    <div key={t.metric} style={{ display: 'flex', alignItems: 'baseline', gap: 8, padding: '3px 0' }}>
                      <span className="mono" style={{ fontSize: 10, color: 'var(--muted)', width: 110, flex: 'none' }}>{t.metric.replace(/_/g, ' ')}</span>
                      <span className={`mono ${worse ? 'tone-crit' : 'tone-ink'}`} style={{ fontSize: 12, fontWeight: 500 }}>
                        {t.display_value ?? t.value}
                      </span>
                      <span className="src-badge" style={{ marginLeft: 'auto' }}>{t.source_system}</span>
                    </div>
                  )
                })}
                {p.source_url && (
                  <div className="mono" style={{ fontSize: 10, marginTop: 8 }}>
                    <a href={p.source_url} target="_blank" rel="noreferrer">source · {p.source_ref ?? 'repo'}</a>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="panel" style={{ gridColumn: '1 / -1' }}>
          <div className="panel-head">
            Client artifact library
            <span className="panel-note">site visits · architecture · capacity plans · incidents · feature requests · accelerators</span>
          </div>
          {data.artifacts.length === 0 && <Empty note="No artifacts catalogued — the missing-artifact control will flag expected ones." />}
          {data.artifacts.map((a) => (
            <div key={a.source_ref + a.title} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 14px', borderBottom: '1px solid var(--line2)' }}>
              <span className="pill muted" style={{ width: 128, justifyContent: 'center' }}>{ARTIFACT_KIND[a.kind] ?? a.kind}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <a href={a.url} target="_blank" rel="noreferrer" style={{ font: "500 12.5px/1.3 'Instrument Sans',sans-serif" }}>{a.title}</a>
                {a.summary && (
                  <div style={{ font: "400 11px/1.4 'Instrument Sans',sans-serif", color: 'var(--muted)', marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {a.summary}
                  </div>
                )}
              </div>
              <span className={`pill ${a.status === 'approved' || a.status === 'final' || a.status === 'adopted' ? 'good' : a.status === 'open' ? 'warn' : 'muted'}`}>{a.status.replace('_', ' ')}</span>
              <span className="src-badge">{a.source_system}</span>
              <span className="mono" style={{ fontSize: 10, color: 'var(--faint)', width: 120, textAlign: 'right', flex: 'none' }}>
                {a.authored_by ?? ''} · {shortDate(a.authored_at)}
              </span>
            </div>
          ))}
        </div>

      </div>
    </div>
  )
}

const ARTIFACT_KIND: Record<string, string> = {
  site_visit_report: 'site visit',
  target_architecture: 'architecture',
  capacity_plan: 'capacity plan',
  incident_review: 'incident review',
  feature_request: 'feature request',
  accelerator: 'accelerator',
  runbook: 'runbook',
  doc: 'document',
}

function Tile({ label, value, unit, sub, src, tone = 'ink' }: { label: string; value: string; unit?: string; sub?: string; src: string; tone?: string }) {
  return (
    <div style={{ border: '1px solid var(--line)', borderRadius: 6, padding: '11px 12px', background: 'var(--surface2)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 9 }}>
        <span className="mono" style={{ fontSize: 9.5, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--faint)' }}>{label}</span>
        <span className="src-badge">{src}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
        <span className={`mono tone-${tone}`} style={{ fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>{value}</span>
        {unit && <span className="mono" style={{ fontSize: 10.5, color: 'var(--faint)' }}>{unit}</span>}
      </div>
      {sub && <div style={{ font: "400 10.5px/1.4 'Instrument Sans',sans-serif", color: 'var(--muted)', marginTop: 6 }}>{sub}</div>}
    </div>
  )
}

function Empty({ note }: { note: string }) {
  return <div style={{ padding: 14, font: "400 12px/1.5 'Instrument Sans',sans-serif", color: 'var(--faint)' }}>{note}</div>
}
