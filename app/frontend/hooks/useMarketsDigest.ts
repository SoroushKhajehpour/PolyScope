import { useCallback, useEffect, useRef, useState } from "react"
import type { DigestMarketEntry } from "@/types/market"

function csrfToken(): string {
  const el = document.querySelector('meta[name="csrf-token"]')
  return el?.getAttribute("content") ?? ""
}

export function useMarketsDigest(eventIds: string[], pollMs = 60_000) {
  const [byEventId, setByEventId] = useState<Record<string, DigestMarketEntry>>({})
  const idsKey = [...eventIds].sort().join(",")
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const fetchDigest = useCallback(async () => {
    if (eventIds.length === 0) {
      setByEventId({})
      return
    }

    const res = await fetch("/markets/digest", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ event_ids: eventIds }),
    })

    if (!res.ok) return

    const json = (await res.json()) as { markets?: Record<string, DigestMarketEntry> }
    const raw = json.markets ?? {}
    setByEventId(raw)
  }, [eventIds])

  useEffect(() => {
    void fetchDigest()
  }, [fetchDigest, idsKey])

  useEffect(() => {
    if (pollMs <= 0 || eventIds.length === 0) return

    const tick = () => {
      if (typeof document !== "undefined" && document.visibilityState !== "visible") return
      void fetchDigest()
    }

    timerRef.current = setInterval(tick, pollMs)
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [fetchDigest, pollMs, idsKey, eventIds.length])

  return { byEventId, refresh: fetchDigest }
}
