import { router } from "@inertiajs/react"
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
      <div className="mx-auto w-full max-w-4xl py-10 lg:py-12">
        <button
          type="button"
          onClick={() => router.visit("/")}
          className="group mb-6 flex items-center gap-1.5 text-[13px] font-medium text-slate-500 transition hover:text-slate-200"
        >
          <svg
            className="h-3.5 w-3.5 transition-transform group-hover:-translate-x-0.5"
            viewBox="0 0 16 16"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M10 12L6 8l4-4" />
          </svg>
          Back
        </button>

        {risk_score ? (
          <div className="space-y-6">
            <MarketHero market={market} riskScore={risk_score} />
            <MarketSummaryCard riskScore={risk_score} />
            <MarketAnalysisTabs riskScore={risk_score} />
          </div>
        ) : (
          <div className="space-y-6">
            <MarketHero market={market} riskScore={null} />
            <div className="rounded-md border border-white/8 bg-white/3 p-6">
              <p className="text-sm text-slate-300">Risk score is not available for this market yet.</p>
            </div>
          </div>
        )}
      </div>
    </Layout>
  )
}
