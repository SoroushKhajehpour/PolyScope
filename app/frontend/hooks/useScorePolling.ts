import { useEffect, useRef } from "react"
import { marketPath } from "@/lib/utils"

const POLL_MS = 4000
/** ~3 min of pending:true then hard reload (serial polls, slower interval). */
const RELOAD_AFTER_PENDING_POLLS = 45

type ScorePollJson = { pending?: boolean; score?: number; error?: string }

/**
 * Polls score_result until the server reports not pending, then calls onScoreReady once.
 * Polls are serialized (next request only after the previous finishes) to avoid overlapping fetches.
 */
export function useScorePolling(eventId: string, onScoreReady: () => void, intervalMs = POLL_MS) {
  const pendingStreakRef = useRef(0)

  useEffect(() => {
    let cancelled = false
    let timeoutId: ReturnType<typeof setTimeout> | null = null

    const clearScheduled = () => {
      if (timeoutId) {
        clearTimeout(timeoutId)
        timeoutId = null
      }
    }

    const scheduleNext = () => {
      clearScheduled()
      if (cancelled) return
      timeoutId = setTimeout(runPoll, intervalMs)
    }

    function runPoll() {
      if (cancelled) return
      timeoutId = null

      fetch(`${marketPath(eventId)}/score_result.json`, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      })
        .then(async (r) => {
          if (cancelled) return null
          return (await r.json().catch(() => null)) as ScorePollJson | null
        })
        .then((data) => {
          if (cancelled) return

          if (!data) {
            pendingStreakRef.current += 1
            if (pendingStreakRef.current >= RELOAD_AFTER_PENDING_POLLS) {
              pendingStreakRef.current = 0
              window.location.assign(marketPath(eventId))
              return
            }
            scheduleNext()
            return
          }

          const stillPending = data.pending === true || data.pending === "true"
          if (stillPending) {
            pendingStreakRef.current += 1
            if (pendingStreakRef.current >= RELOAD_AFTER_PENDING_POLLS) {
              pendingStreakRef.current = 0
              window.location.assign(marketPath(eventId))
              return
            }
            scheduleNext()
            return
          }

          pendingStreakRef.current = 0
          onScoreReady()
        })
        .catch(() => {
          if (cancelled) return
          scheduleNext()
        })
    }

    pendingStreakRef.current = 0
    runPoll()

    return () => {
      cancelled = true
      clearScheduled()
    }
  }, [eventId, intervalMs, onScoreReady])
}
