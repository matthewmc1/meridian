import { useState } from 'react'
import { api, type SignalCustomer } from './api'

// Minimal but real write path: raising a risk POSTs to /api/journal, which
// appends the opening movement. The button is no longer inert.
export default function RaiseRiskModal({
  customers, defaultCustomerId, onClose, onDone,
}: {
  customers: SignalCustomer[]
  defaultCustomerId?: string
  onClose: () => void
  onDone: (riskRef: string) => void
}) {
  const [customerId, setCustomerId] = useState(defaultCustomerId ?? customers[0]?.customer_id ?? '')
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [severity, setSeverity] = useState('P2')
  const [owner, setOwner] = useState('P. Raman')
  const [dueAt, setDueAt] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  const submit = async () => {
    if (!title.trim()) { setErr('Title is required'); return }
    setBusy(true); setErr(null)
    try {
      const cust = customers.find((c) => c.customer_id === customerId)
      const res = await api.raiseRisk({
        title, body, customer_id: customerId, scope_label: cust?.name ?? '',
        severity, tone: severity === 'P1' ? 'crit' : 'warn', owner,
        action_label: 'REVIEW', action_view: 'client', due_at: dueAt || undefined,
      })
      onDone(res.risk_ref)
    } catch (e) {
      setErr(String(e)); setBusy(false)
    }
  }

  const field: React.CSSProperties = {
    width: '100%', height: 32, padding: '0 10px', borderRadius: 5, border: '1px solid var(--line)',
    background: 'var(--surface)', color: 'var(--ink)', font: "400 12.5px/1 'Instrument Sans',sans-serif",
  }
  const lbl: React.CSSProperties = { font: "600 9.5px/1 'IBM Plex Mono',monospace", letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--faint)', marginBottom: 6, display: 'block' }

  return (
    <div onClick={onClose} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.35)', display: 'grid', placeItems: 'center', zIndex: 50 }}>
      <div onClick={(e) => e.stopPropagation()} style={{ width: 460, background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: 9, padding: 22, boxShadow: '0 30px 70px -30px rgba(0,0,0,0.6)' }}>
        <div style={{ font: "600 15px/1.2 'Instrument Sans',sans-serif", marginBottom: 14 }}>Raise a risk</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div>
            <label style={lbl}>Client</label>
            <select style={field} value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
              {customers.map((c) => <option key={c.customer_id} value={c.customer_id}>{c.name}</option>)}
            </select>
          </div>
          <div><label style={lbl}>Title</label><input style={field} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="What is the risk?" /></div>
          <div><label style={lbl}>Detail</label><textarea style={{ ...field, height: 64, padding: '8px 10px' }} value={body} onChange={(e) => setBody(e.target.value)} /></div>
          <div style={{ display: 'flex', gap: 10 }}>
            <div style={{ flex: 1 }}><label style={lbl}>Severity</label>
              <select style={field} value={severity} onChange={(e) => setSeverity(e.target.value)}><option>P1</option><option>P2</option></select></div>
            <div style={{ flex: 1 }}><label style={lbl}>Owner</label><input style={field} value={owner} onChange={(e) => setOwner(e.target.value)} /></div>
            <div style={{ flex: 1 }}><label style={lbl}>Due</label><input type="date" style={field} value={dueAt} onChange={(e) => setDueAt(e.target.value)} /></div>
          </div>
          {err && <div style={{ color: 'var(--crit)', font: "400 11.5px/1.4 'Instrument Sans',sans-serif" }}>{err}</div>}
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 4 }}>
            <button className="btn-ghost" onClick={onClose}>Cancel</button>
            <button className="btn-primary" onClick={submit} disabled={busy}>{busy ? 'Raising…' : 'Raise risk'}</button>
          </div>
        </div>
      </div>
    </div>
  )
}
