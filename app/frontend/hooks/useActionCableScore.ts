import { useEffect } from "react"
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()

/** Fires onScoreReady when the server broadcasts score_complete (dedupe with parent ref). */
export function useActionCableScore(marketId: number, _eventId: string, onScoreReady: () => void) {
  useEffect(() => {
    const subscription = consumer.subscriptions.create(
      { channel: "ScoreChannel", market_id: marketId },
      {
        received(data: { event: string }) {
          if (data.event === "score_complete") {
            onScoreReady()
          }
        },
      }
    )

    return () => {
      subscription.unsubscribe()
    }
  }, [marketId, onScoreReady])
}
