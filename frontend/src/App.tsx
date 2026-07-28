import { useEffect, useState } from 'react'
import { api, ago, money, type CorrelationResponse, type SourceStatus } from './api'
import Signal from './views/Signal'
import Customer360 from './views/Customer360'
import Journal from './views/Journal'
import Correlation from './views/Correlation'
import Rag from './views/Rag'
import Delivery from './views/Delivery'

export type View = 'signal' | 'rag' | 'customer' | 'delivery' | 'correlate' | 'journal'

const NAV: { view: View; label: string }[] = [
  { view: 'signal', label: 'Customer signal' },
  { view: 'rag', label: 'RAG board' },
  { view: 'customer', label: 'Customer 360' },
  { view: 'delivery', label: 'Delivery & risk' },
  { view: 'correlate', label: 'Correlation' },
  { view: 'journal', label: 'Risk journal' },
]

export default function App() {
  const [view, setView] = useState<View>('signal')
  const [customerId, setCustomerId] = useState<string | null>(null)
  const [theme, setTheme] = useState<'light' | 'dark'>(
    () => (localStorage.getItem('meridian-theme') as 'light' | 'dark') || 'light',
  )
  const [sources, setSources] = useState<SourceStatus[]>([])
  const [corr, setCorr] = useState<CorrelationResponse | null>(null)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('meridian-theme', theme)
  }, [theme])

  useEffect(() => {
    api.health().then((h) => setSources(h.sources)).catch(() => setSources([]))
    api.correlation().then(setCorr).catch(() => setCorr(null))
  }, [])

  const openCustomer = (id: string) => {
    setCustomerId(id)
    setView('customer')
  }

  const impacted = corr?.affected.filter((a) => a.impact !== 'not_vulnerable') ?? []
  const exposedAcv = impacted.reduce((s, a) => s + (a.acv_pennies ?? 0), 0)

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">M</div>
          <div>
            <div className="brand-name">Meridian</div>
            <div className="brand-sub">Client Assurance</div>
          </div>
        </div>
        <nav className="nav">
          {NAV.map((n) => (
            <button
              key={n.view}
              className={`nav-item${view === n.view ? ' active' : ''}`}
              onClick={() => setView(n.view)}
            >
              <span className="nav-bar" />
              <span style={{ flex: 1 }}>{n.label}</span>
            </button>
          ))}
        </nav>
        <div className="sidebar-foot">
          <div className="foot-heading">Sources</div>
          {sources.map((s) => (
            <div key={s.source_system} className="source-row">
              <span
                className="source-dot"
                style={{
                  background:
                    s.lag_seconds != null && s.lag_seconds < 4 * 3600 ? 'var(--good)' : 'var(--warn)',
                }}
              />
              <span>{s.source_system}</span>
              <span className="source-age">{ago(s.last_success)}</span>
            </div>
          ))}
          {sources.length === 0 && (
            <div className="source-row" style={{ color: 'var(--faint)' }}>
              api unreachable
            </div>
          )}
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div className="search mono">⌕&ensp;Clients, risks, clauses, epics…</div>
          {corr?.vulnerability && impacted.length > 0 ? (
            <div className="banner">
              <span className="banner-dot" />
              <span className="banner-label">Customer signal</span>
              <span className="banner-text">
                {corr.vulnerability.ref} · {corr.vulnerability.service_name} — {impacted.length}{' '}
                clients, {money(exposedAcv)} ACV exposed
              </span>
              <button className="banner-action" onClick={() => setView('correlate')}>
                TRIAGE →
              </button>
            </div>
          ) : (
            <div style={{ flex: 1 }} />
          )}
          <button
            className="icon-btn"
            title="Toggle light / dark"
            onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}
          >
            ◐
          </button>
        </header>

        <main className="content">
          {view === 'signal' && <Signal onOpenCustomer={openCustomer} />}
          {view === 'rag' && <Rag onOpenCustomer={openCustomer} />}
          {view === 'customer' && (
            <Customer360 customerId={customerId} onBack={() => setView('signal')} onPick={openCustomer} />
          )}
          {view === 'delivery' && <Delivery customerId={customerId} onPick={setCustomerId} />}
          {view === 'correlate' && <Correlation onOpenCustomer={openCustomer} />}
          {view === 'journal' && <Journal />}
        </main>
      </div>
    </div>
  )
}
