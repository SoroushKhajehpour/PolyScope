import { useEffect } from "react"
import { router } from "@inertiajs/react"
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()

export function useActionCableScore(marketId: number, eventId: string) {
  useEffect(() => {
    const subscription = consumer.subscriptions.create(
      { channel: "ScoreChannel", market_id: marketId },
      {
        received(data: { event: string }) {
          if (data.event === "score_complete") {
            router.visit(`/markets/${eventId}`, { preserveState: false })
          }
        },
      }
    )

    return () => {
      subscription.unsubscribe()
    }
  }, [marketId, eventId])
}
