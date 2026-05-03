import { router } from "@inertiajs/react"
import Layout from "@/components/layout/Layout"
import CriteriaTimeline from "@/components/market/CriteriaTimeline"
import MarketHero from "@/components/market/MarketHero"
import MarketSummaryCard from "@/components/market/MarketSummaryCard"
import MarketAnalysisTabs from "@/components/market/MarketAnalysisTabs"
import ScoreFreshnessBanner from "@/components/market/ScoreFreshnessBanner"
import type { MarketProps, RiskScoreProps, ScoreContextProps } from "@/types/market"

interface Props {
  market: MarketProps
  risk_score: RiskScoreProps | null
  score_context: ScoreContextProps
}

export default function MarketShow({ market, risk_score, score_context }: Props) {
  const timeline = score_context?.criteria_timeline ?? []

  const showStaleBanner =
    Boolean(score_context?.freshness && score_context.freshness !== "fresh" && score_context.stale_reason)

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

        {showStaleBanner && score_context?.stale_reason && score_context?.freshness && (
          <div className="mb-6">
            <ScoreFreshnessBanner freshness={score_context.freshness} message={score_context.stale_reason} />
          </div>
        )}

        {risk_score ? (
          <div className="space-y-6">
            {risk_score.scoring_fallback && (
              <div
                role="status"
                className="rounded-lg border border-amber-500/35 bg-amber-500/10 px-4 py-3 text-[13px] leading-relaxed text-amber-100/95"
              >
                <p className="font-medium text-amber-50">Provisional score</p>
                <p className="mt-1 text-amber-100/85">
                  Full analysis did not complete (often missing{" "}
                  <span className="font-mono text-[12px]">ANTHROPIC_API_KEY</span> or{" "}
                  <span className="font-mono text-[12px]">OPENAI_API_KEY</span>
                  ). The number below is an estimate so the page still loads — fix keys and refresh for a full
                  breakdown.
                </p>
              </div>
            )}
            <MarketHero market={market} riskScore={risk_score} />
            <MarketSummaryCard riskScore={risk_score} />
            <CriteriaTimeline entries={timeline} />
            <MarketAnalysisTabs riskScore={risk_score} />
          </div>
        ) : (
          <div className="space-y-6">
            <MarketHero market={market} riskScore={null} />
            <div className="rounded-md border border-white/8 bg-white/3 p-6">
              <p className="text-sm text-slate-300">Risk score is not available for this market yet.</p>
            </div>
            <CriteriaTimeline entries={timeline} />
          </div>
        )}
      </div>
    </Layout>
  )
}
