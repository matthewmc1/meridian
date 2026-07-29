import { useState } from 'react'
import { api } from './api'

// Records a decision against a risk (raised→DECIDED→verify-by). The decision
// queue's action button is now a real state transition, not a dead control.
export default function DecisionModal({
  journalId, riskRef, title, onClose, onDone,
}: {
  journalId: string
  riskRef: string
  title: string
  onClose: () => void
  onDone: () => void
}) {
  const [option, setOption] = useState('')
  const [rationale, setRationale] = useState('')
  const [decidedBy, setDecidedBy] = useState('P. Raman')
  const [verifyBy, setVerifyBy] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  const submit = async () => {
    if (!option.trim()) { setErr('Decision is required'); return }
    setBusy(true); setErr(null)
    try {
      await api.decide({ journal_id: journalId, option, rationale, decided_by: decidedBy, verify_by: verifyBy || undefined })
      onDone()
    } catch (e) { setErr(String(e)); setBusy(false) }
  }

  const field: React.CSSProperties = {
    width: '100%', height: 32, padding: '0 10px', borderRadius: 5, border: '1px solid var(--line)',
    background: 'var(--surface)', color: 'var(--ink)', font: "400 12.5px/1 'Instrument Sans',sans-serif",
  }
  const lbl: React.CSSProperties = { font: "600 9.5px/1 'IBM Plex Mono',monospace", letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--faint)', marginBottom: 6, display: 'block' }

  return (
    <div onClick={onClose} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.35)', display: 'grid', placeItems: 'center', zIndex: 50 }}>
      <div onClick={(e) => e.stopPropagation()} style={{ width: 460, background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: 9, padding: 22, boxShadow: '0 30px 70px -30px rgba(0,0,0,0.6)' }}>
        <div style={{ font: "600 15px/1.2 'Instrument Sans',sans-serif", marginBottom: 4 }}>Record decision</div>
        <div className="mono" style={{ fontSize: 10.5, color: 'var(--faint)', marginBottom: 14 }}>{riskRef} · {title}</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div><label style={lbl}>Decision</label><input style={field} value={option} onChange={(e) => setOption(e.target.value)} placeholder="What did we decide?" /></div>
          <div><label style={lbl}>Rationale</label><textarea style={{ ...field, height: 56, padding: '8px 10px' }} value={rationale} onChange={(e) => setRationale(e.target.value)} /></div>
          <div style={{ display: 'flex', gap: 10 }}>
            <div style={{ flex: 1 }}><label style={lbl}>Decided by</label><input style={field} value={decidedBy} onChange={(e) => setDecidedBy(e.target.value)} /></div>
            <div style={{ flex: 1 }}><label style={lbl}>Verify by</label><input type="date" style={field} value={verifyBy} onChange={(e) => setVerifyBy(e.target.value)} /></div>
          </div>
          {err && <div style={{ color: 'var(--crit)', font: "400 11.5px/1.4 'Instrument Sans',sans-serif" }}>{err}</div>}
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 4 }}>
            <button className="btn-ghost" onClick={onClose}>Cancel</button>
            <button className="btn-primary" onClick={submit} disabled={busy}>{busy ? 'Saving…' : 'Record decision'}</button>
          </div>
        </div>
      </div>
    </div>
  )
}
