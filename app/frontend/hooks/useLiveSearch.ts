import { useState, useEffect, useRef } from "react"
import type { MarketSearchResult } from "@/types/market"

function isMarketSearchResults(data: unknown): data is MarketSearchResult[] {
  return Array.isArray(data)
}

export function useLiveSearch(query: string, debounceMs = 380) {
  const [results, setResults] = useState<MarketSearchResult[]>([])
  const [loading, setLoading] = useState(false)
  const nonceRef = useRef(0)

  useEffect(() => {
    const trimmed = query.trim()
    if (!trimmed) {
      setResults([])
      setLoading(false)
      return
    }

    setLoading(true)
    nonceRef.current += 1
    const nonce = nonceRef.current

    const controller = new AbortController()
    const timer = setTimeout(() => {
      fetch(`/markets/live_search.json?q=${encodeURIComponent(trimmed)}`, {
        headers: { Accept: "application/json" },
        signal: controller.signal,
      })
        .then(async (r) => {
          if (!r.ok) {
            throw new Error(`live_search_failed_${r.status}`)
          }
          return r.json()
        })
        .then((data: unknown) => {
          if (nonce === nonceRef.current) {
            setResults(isMarketSearchResults(data) ? data : [])
            setLoading(false)
          }
        })
        .catch((error: unknown) => {
          if ((error as { name?: string })?.name === "AbortError") {
            return
          }
          if (nonce === nonceRef.current) {
            setResults([])
            setLoading(false)
          }
        })
    }, debounceMs)

    return () => {
      clearTimeout(timer)
      controller.abort()
    }
  }, [query, debounceMs])

  return { results, loading }
}
