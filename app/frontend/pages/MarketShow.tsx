import Layout from "@/components/layout/Layout"
import MarketHero from "@/components/market/MarketHero"
import MarketSummaryCard from "@/components/market/MarketSummaryCard"
import MarketAnalysisTabs from "@/components/market/MarketAnalysisTabs"
import type { MarketProps, RiskScoreProps } from "@/types/market"

interface Props {
  market: MarketProps
  risk_score: RiskScoreProps | null
}

export default function MarketShow({ market, risk_score }: Props) {
  return (
    <Layout centerContent>
      <div className="mx-auto w-full max-w-4xl px-4 py-10 sm:px-6 lg:py-12">
        {risk_score ? (
          <div className="space-y-10 lg:space-y-12">
            <MarketHero market={market} riskScore={risk_score} />
            <MarketSummaryCard riskScore={risk_score} />
            <MarketAnalysisTabs riskScore={risk_score} />
          </div>
        ) : (
          <div className="space-y-10 lg:space-y-12">
            <MarketHero market={market} riskScore={null} />
            <div className="rounded-2xl border border-white/10 bg-[#0F1420]/70 p-7 backdrop-blur">
              <p className="text-sm text-slate-400">Risk score is not available for this market yet.</p>
            </div>
          </div>
        )}
      </div>
    </Layout>
  )
}
