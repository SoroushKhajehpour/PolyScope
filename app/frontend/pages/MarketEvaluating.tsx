import Layout from "@/components/layout/Layout"
import CriteriaTimeline from "@/components/market/CriteriaTimeline"
import EvaluatingCard from "@/components/market/EvaluatingCard"
import { useScorePolling } from "@/hooks/useScorePolling"
import { useActionCableScore } from "@/hooks/useActionCableScore"
import type { MarketProps, ScoreContextProps } from "@/types/market"

interface Props {
  market: MarketProps
  score_context?: ScoreContextProps
}

export default function MarketEvaluating({ market, score_context }: Props) {
  useScorePolling(market.event_id)
  useActionCableScore(market.id, market.event_id)

  const timeline = score_context?.criteria_timeline ?? []

  return (
    <Layout>
      <div
        className="flex min-h-screen flex-col items-center justify-center px-4 py-12"
        style={{
          background: "#0a0e1a",
          backgroundImage: "radial-gradient(rgba(255,255,255,0.03) 1px, transparent 1px)",
          backgroundSize: "24px 24px",
        }}
      >
        <div className="w-full max-w-lg space-y-8">
          <EvaluatingCard market={market} />
          {timeline.length > 0 && (
            <CriteriaTimeline entries={timeline} />
          )}
        </div>
      </div>
    </Layout>
  )
}
