import { useEffect, useRef } from "react"
import { router } from "@inertiajs/react"
import { marketPath } from "@/lib/utils"

const POLL_MS = 2000
/** ~90s of pending:true then hard reload (Sidekiq stuck, cache oddities) */
const RELOAD_AFTER_PENDING_POLLS = 45

type ScorePollJson = { pending?: boolean; score?: number; error?: string }

export function useScorePolling(eventId: string, intervalMs = POLL_MS) {
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const pendingStreakRef = useRef(0)

  useEffect(() => {
    const poll = () => {
      fetch(`${marketPath(eventId)}/score_result.json`, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      })
        .then(async (r) => {
          const data = (await r.json().catch(() => null)) as ScorePollJson | null
          if (!data) {
            pendingStreakRef.current += 1
            if (pendingStreakRef.current >= RELOAD_AFTER_PENDING_POLLS) {
              pendingStreakRef.current = 0
              window.location.assign(marketPath(eventId))
            }
            return
          }

          if (data.pending === true) {
            pendingStreakRef.current += 1
            if (pendingStreakRef.current >= RELOAD_AFTER_PENDING_POLLS) {
              pendingStreakRef.current = 0
              window.location.assign(marketPath(eventId))
            }
            return
          }

          pendingStreakRef.current = 0
          if (data.score !== undefined) {
            if (timerRef.current) clearInterval(timerRef.current)
            router.visit(marketPath(eventId), { preserveState: false })
          }
        })
        .catch(() => {})
    }

    pendingStreakRef.current = 0
    poll()
    timerRef.current = setInterval(poll, intervalMs)

    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [eventId, intervalMs])
}
