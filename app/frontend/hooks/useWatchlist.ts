import { useCallback, useEffect, useMemo, useState } from "react"

const STORAGE_V2 = "polyscope_watchlist_v2"
const LEGACY_IDS = "polyscope_watchlist_event_ids"
const MAX_ITEMS = 50

export interface WatchedMarket {
  event_id: string
  title: string
}

function migrateLegacy(): WatchedMarket[] {
  if (typeof window === "undefined") return []
  try {
    const raw = window.localStorage.getItem(LEGACY_IDS)
    if (!raw) return []
    const parsed = JSON.parse(raw) as unknown
    if (!Array.isArray(parsed)) return []
    const items = parsed
      .map(String)
      .filter(Boolean)
      .slice(0, MAX_ITEMS)
      .map((event_id) => ({ event_id, title: event_id }))
    window.localStorage.removeItem(LEGACY_IDS)
    return items
  } catch {
    return []
  }
}

function readItems(): WatchedMarket[] {
  if (typeof window === "undefined") return []
  try {
    const raw = window.localStorage.getItem(STORAGE_V2)
    if (!raw) {
      const migrated = migrateLegacy()
      if (migrated.length) writeItems(migrated)
      return migrated
    }
    const parsed = JSON.parse(raw) as unknown
    if (!Array.isArray(parsed)) return []
    return parsed
      .map((row) => {
        if (row && typeof row === "object" && "event_id" in row) {
          const r = row as { event_id?: string; title?: string }
          const id = String(r.event_id ?? "").trim()
          if (!id) return null
          return { event_id: id, title: String(r.title ?? id).trim() || id }
        }
        return null
      })
      .filter((x): x is WatchedMarket => x != null)
      .slice(0, MAX_ITEMS)
  } catch {
    return migrateLegacy()
  }
}

function writeItems(items: WatchedMarket[]): void {
  window.localStorage.setItem(STORAGE_V2, JSON.stringify(items.slice(0, MAX_ITEMS)))
}

export function useWatchlist() {
  const [items, setItems] = useState<WatchedMarket[]>([])

  useEffect(() => {
    setItems(readItems())
  }, [])

  const ids = useMemo(() => items.map((x) => x.event_id), [items])

  const add = useCallback((eventId: string, title?: string) => {
    if (!eventId) return
    const label = (title ?? eventId).trim() || eventId
    setItems((prev) => {
      const rest = prev.filter((x) => x.event_id !== eventId)
      const next = [{ event_id: eventId, title: label }, ...rest].slice(0, MAX_ITEMS)
      writeItems(next)
      return next
    })
  }, [])

  const remove = useCallback((eventId: string) => {
    setItems((prev) => {
      const next = prev.filter((x) => x.event_id !== eventId)
      writeItems(next)
      return next
    })
  }, [])

  const toggle = useCallback((eventId: string, title?: string) => {
    setItems((prev) => {
      const has = prev.some((x) => x.event_id === eventId)
      const next = has
        ? prev.filter((x) => x.event_id !== eventId)
        : [{ event_id: eventId, title: (title ?? eventId).trim() || eventId }, ...prev].slice(
            0,
            MAX_ITEMS
          )
      writeItems(next)
      return next
    })
  }, [])

  const isWatched = useCallback(
    (eventId: string) => items.some((x) => x.event_id === eventId),
    [items]
  )

  return { items, ids, add, remove, toggle, isWatched }
}
