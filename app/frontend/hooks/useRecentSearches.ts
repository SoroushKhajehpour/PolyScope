import { useState, useEffect } from "react"

const STORAGE_KEY = "polyscope_recent_searches"
const MAX_ITEMS = 8

export function useRecentSearches() {
  const [searches, setSearches] = useState<string[]>([])

  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored) setSearches(JSON.parse(stored))
    } catch {
      // ignore
    }
  }, [])

  const persist = (items: string[]) => {
    setSearches(items)
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(items))
    } catch {
      // ignore
    }
  }

  const add = (query: string) => {
    const trimmed = query.trim()
    if (!trimmed) return
    const filtered = searches.filter((s) => s !== trimmed)
    persist([trimmed, ...filtered].slice(0, MAX_ITEMS))
  }

  const remove = (index: number) => {
    persist(searches.filter((_, i) => i !== index))
  }

  const clearAll = () => {
    persist([])
  }

  return { searches, add, remove, clearAll }
}
