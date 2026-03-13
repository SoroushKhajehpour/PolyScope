import Layout from "@/components/layout/Layout"
import MarketHero from "@/components/market/MarketHero"
import RiskScoreCard from "@/components/market/RiskScoreCard"
import type { MarketProps, RiskScoreProps } from "@/types/market"

interface Props {
  market: MarketProps
  risk_score: RiskScoreProps | null
}

export default function MarketShow({ market, risk_score }: Props) {
  return (
    <Layout>
      <div className="mx-auto max-w-[760px] px-4 py-8">
        {risk_score ? (
          <RiskScoreCard market={market} riskScore={risk_score} />
        ) : (
          <div className="space-y-8 text-left">
            <MarketHero market={market} />
            <div className="rounded-xl border border-white/10 bg-[#0F1420] p-6">
              <p className="text-sm text-white/50">Risk score is not available for this market yet.</p>
            </div>
          </div>
        )}
      </div>
    </Layout>
  )
}
