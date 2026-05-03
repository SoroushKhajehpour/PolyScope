import { useMemo, useState } from "react"
import type { RiskScoreProps } from "@/types/market"
import ResolutionTab from "./tabs/ResolutionTab"
import RiskFactorsTab from "./tabs/RiskFactorsTab"
import InsightsTab from "./tabs/InsightsTab"

interface MarketAnalysisTabsProps {
  riskScore: RiskScoreProps
}

type TabId = "resolution" | "risk_factors" | "insights"

const TABS: Array<{ id: TabId; label: string }> = [
  { id: "resolution", label: "Resolution" },
  { id: "risk_factors", label: "Risk Factors" },
  { id: "insights", label: "Insights" },
]

export default function MarketAnalysisTabs({ riskScore }: MarketAnalysisTabsProps) {
  const [activeTab, setActiveTab] = useState<TabId>("resolution")

  const content = useMemo(() => {
    switch (activeTab) {
      case "resolution":
        return <ResolutionTab criteria={riskScore.resolution_criteria} />
      case "risk_factors":
        return <RiskFactorsTab factors={riskScore.factors} />
      case "insights":
        return (
          <InsightsTab
            topDrivers={riskScore.top_risk_drivers}
            whyNotHigherRisk={riskScore.why_not_higher_risk}
            liquidity={riskScore.liquidity}
            unavailableSources={riskScore.data_sources_unavailable}
            similarResolvedMarkets={riskScore.similar_resolved_markets ?? []}
          />
        )
      default:
        return null
    }
  }, [activeTab, riskScore])

  return (
    <section className="space-y-0">
      {/* Tab bar */}
      <div className="flex gap-0 border-b border-white/8">
        {TABS.map((tab) => {
          const isActive = tab.id === activeTab
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={`relative px-5 py-2.5 text-[11px] font-semibold uppercase tracking-[0.14em] transition-colors ${
                isActive
                  ? "text-white"
                  : "text-slate-500 hover:text-slate-300"
              }`}
            >
              {tab.label}
              {isActive && (
                <span className="absolute inset-x-0 bottom-0 h-[2px] bg-cyan-400" />
              )}
            </button>
          )
        })}
      </div>

      {/* Tab content */}
      <div className="pt-5">{content}</div>
    </section>
  )
}
