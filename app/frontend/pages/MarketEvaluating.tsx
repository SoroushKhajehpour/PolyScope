import { useCallback, useEffect } from "react"
import { router } from "@inertiajs/react"
import Layout from "@/components/layout/Layout"
import EvaluatingCard from "@/components/market/EvaluatingCard"
import { useScorePolling } from "@/hooks/useScorePolling"
import { useActionCableScore } from "@/hooks/useActionCableScore"
import { releaseMarketEvaluatingNavLock, tryNavigateToMarketOnce } from "@/lib/marketEvaluatingNav"
import { marketPath } from "@/lib/utils"
import type { MarketProps } from "@/types/market"

interface Props {
  market: MarketProps
}

export default function MarketEvaluating({ market }: Props) {
  useEffect(() => {
    releaseMarketEvaluatingNavLock(market.event_id)
  }, [market.event_id])

  const goToMarket = useCallback(() => {
    tryNavigateToMarketOnce(market.event_id, () => {
      router.visit(marketPath(market.event_id), { preserveState: false })
    })
  }, [market.event_id])

  useScorePolling(market.event_id, goToMarket)
  useActionCableScore(market.id, market.event_id, goToMarket)

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
        <div className="w-full max-w-lg">
          <EvaluatingCard market={market} />
        </div>
      </div>
    </Layout>
  )
}
