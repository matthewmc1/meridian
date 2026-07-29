import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { api, type DefinitionRow } from './api'

// The console reads its banding thresholds from core.definition (served at
// /api/definitions) instead of hard-coding them per view — the single-source
// fix for the definition-drift finding. Fallbacks match the seeded definition
// rows so a view still renders before the fetch resolves.
type Defs = Record<string, DefinitionRow>
const DefsCtx = createContext<Defs>({})

export function DefsProvider({ children }: { children: ReactNode }) {
  const [defs, setDefs] = useState<Defs>({})
  useEffect(() => {
    api.definitions()
      .then((d) => setDefs(Object.fromEntries(d.definitions.map((x) => [x.key, x]))))
      .catch(() => setDefs({}))
  }, [])
  return <DefsCtx.Provider value={defs}>{children}</DefsCtx.Provider>
}

export function useDefs() {
  return useContext(DefsCtx)
}

// thr('utilisation','crit',105) → threshold from the lake, else the fallback.
export function useThr() {
  const defs = useDefs()
  return (key: string, name: string, fallback: number): number => {
    const t = defs[key]?.thresholds as Record<string, unknown> | undefined
    const v = t?.[name]
    return typeof v === 'number' ? v : fallback
  }
}

// A definition tooltip: the prose + formula a CSM can read to a client.
export function DefTip({ k, label }: { k: string; label?: string }) {
  const defs = useDefs()
  const d = defs[k]
  if (!d) return null
  return (
    <span
      title={`${d.title}\n\n${d.definition}${d.formula ? `\n\n${d.formula}` : ''}`}
      style={{
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        width: 13, height: 13, borderRadius: '50%', border: '1px solid var(--line)',
        color: 'var(--faint)', font: "600 8px/1 'IBM Plex Mono',monospace", cursor: 'help', marginLeft: 5,
      }}
    >
      {label ?? '?'}
    </span>
  )
}
