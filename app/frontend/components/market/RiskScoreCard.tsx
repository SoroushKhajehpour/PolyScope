import type { MarketProps, RiskScoreProps } from "@/types/market"
import MarketHero from "./MarketHero"
import ScoreRing from "./ScoreRing"
import FactorBreakdown from "./FactorBreakdown"
import ResolutionCriteria from "./ResolutionCriteria"
import InsightsPanel from "./InsightsPanel"

const SECTION_CARD_CLASS =
  "rounded-xl border border-white/10 bg-[#0F1420] p-6"

interface RiskScoreCardProps {
  market: MarketProps
  riskScore: RiskScoreProps
}

function confidenceLabel(tier: string | null): string {
  if (!tier) return "Confidence unknown"
  const t = tier.toLowerCase()
  if (t === "low") return "Low confidence"
  if (t === "medium" || t === "medium_low") return "Medium confidence"
  if (t === "high") return "High confidence"
  return `${tier.replace(/_/g, " ")} confidence`
}

function liquidityLabel(label: string | null): string {
  if (!label) return ""
  return label.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())
}

export default function RiskScoreCard({ market, riskScore }: RiskScoreCardProps) {
  const riskHeading =
    riskScore.level.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase()) + " Risk"

  return (
    <div className="space-y-8 text-left">
      <MarketHero market={market} />

      {/* Risk score section */}
      <div className={SECTION_CARD_CLASS}>
        <div className="flex flex-wrap items-start gap-6 sm:flex-nowrap">
          <ScoreRing score={riskScore.score} />
          <div className="min-w-0 flex-1 space-y-3">
            <h2 className="text-xl font-semibold text-white">{riskHeading}</h2>
            <div className="flex flex-wrap gap-2">
              <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-xs text-white/60">
                {confidenceLabel(riskScore.confidence_tier)}
              </span>
              {riskScore.liquidity?.label && (
                <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-xs text-white/60">
                  {liquidityLabel(riskScore.liquidity.label)}
                </span>
              )}
            </div>
            {riskScore.summary && (
              <p className="text-[15px] leading-relaxed text-white/80">
                {riskScore.summary}
              </p>
            )}
            {riskScore.confidence_note && (
              <p className="text-xs text-white/50">{riskScore.confidence_note}</p>
            )}
          </div>
        </div>
      </div>

      {riskScore.resolution_criteria && (
        <ResolutionCriteria criteria={riskScore.resolution_criteria} />
      )}

      <FactorBreakdown factors={riskScore.factors} />

      <InsightsPanel
        topDrivers={riskScore.top_risk_drivers}
        whyNotHigherRisk={riskScore.why_not_higher_risk}
        liquidity={riskScore.liquidity}
        unavailableSources={riskScore.data_sources_unavailable}
      />
    </div>
  )
}
