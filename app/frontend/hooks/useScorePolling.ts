import { useEffect, useRef } from "react"
import { router } from "@inertiajs/react"

export function useScorePolling(eventId: string, scorePollAfter: number, intervalMs = 8000) {
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  useEffect(() => {
    const poll = () => {
      const qs = new URLSearchParams({ after: String(scorePollAfter) })
      fetch(`/markets/${eventId}/score_result.json?${qs}`, {
        headers: { Accept: "application/json" },
      })
        .then((r) => {
          if (r.status === 204) return null
          if (!r.ok) return null
          return r.json()
        })
        .then((data) => {
          if (data && data.score !== undefined) {
            if (timerRef.current) clearInterval(timerRef.current)
            router.visit(`/markets/${eventId}`, { preserveState: false })
          }
        })
        .catch(() => {})
    }

    // Initial check
    poll()
    timerRef.current = setInterval(poll, intervalMs)

    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [eventId, scorePollAfter, intervalMs])
}
