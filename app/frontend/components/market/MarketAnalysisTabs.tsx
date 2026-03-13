import { useMemo, useState } from "react"
import type { RiskScoreProps } from "@/types/market"
import ResolutionTab from "./tabs/ResolutionTab"
import RiskFactorsTab from "./tabs/RiskFactorsTab"
import FactorBreakdownTab from "./tabs/FactorBreakdownTab"
import InsightsTab from "./tabs/InsightsTab"

interface MarketAnalysisTabsProps {
  riskScore: RiskScoreProps
}

type TabId = "resolution" | "risk_factors" | "factor_breakdown" | "insights"

const TABS: Array<{ id: TabId; label: string }> = [
  { id: "resolution", label: "Resolution" },
  { id: "risk_factors", label: "Risk Factors" },
  { id: "factor_breakdown", label: "Factor Breakdown" },
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
      case "factor_breakdown":
        return <FactorBreakdownTab criteria={riskScore.resolution_criteria} />
      case "insights":
        return (
          <InsightsTab
            topDrivers={riskScore.top_risk_drivers}
            whyNotHigherRisk={riskScore.why_not_higher_risk}
            liquidity={riskScore.liquidity}
            unavailableSources={riskScore.data_sources_unavailable}
          />
        )
      default:
        return null
    }
  }, [activeTab, riskScore])

  return (
    <section className="space-y-4">
      <h2 className="text-xl font-semibold text-white">Market analysis</h2>

      <div className="overflow-x-auto">
        <div className="inline-flex min-w-full gap-2 rounded-xl border border-white/10 bg-[#0F1420] p-2">
          {TABS.map((tab) => {
            const isActive = tab.id === activeTab
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`rounded-lg px-4 py-2 text-sm whitespace-nowrap transition ${
                  isActive
                    ? "bg-[#1D4ED8] text-white"
                    : "bg-transparent text-white/65 hover:bg-white/5 hover:text-white/90"
                }`}
              >
                {tab.label}
              </button>
            )
          })}
        </div>
      </div>

      {content}
    </section>
  )
}
