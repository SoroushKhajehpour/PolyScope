import Layout from "@/components/layout/Layout"
import EvaluatingCard from "@/components/market/EvaluatingCard"
import { useScorePolling } from "@/hooks/useScorePolling"
import { useActionCableScore } from "@/hooks/useActionCableScore"
import type { MarketEvaluatingProps } from "@/types/market"

export default function MarketEvaluating({ market, score_poll_after }: MarketEvaluatingProps) {
  useScorePolling(market.event_id, score_poll_after)
  useActionCableScore(market.id, market.event_id)

  return (
    <Layout>
      <div
        className="flex min-h-screen flex-col items-center justify-center px-4"
        style={{
          background: "#0a0e1a",
          backgroundImage: "radial-gradient(rgba(255,255,255,0.03) 1px, transparent 1px)",
          backgroundSize: "24px 24px",
        }}
      >
        <EvaluatingCard market={market} />
      </div>
    </Layout>
  )
}
