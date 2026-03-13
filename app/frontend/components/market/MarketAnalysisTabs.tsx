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
          />
        )
      default:
        return null
    }
  }, [activeTab, riskScore])

  return (
    <section className="space-y-5">
      <h2 className="text-2xl font-bold text-white">Market analysis</h2>

      <div className="overflow-x-auto">
        <div className="inline-flex min-w-full gap-2 rounded-2xl border border-white/10 bg-[#0F1420]/75 p-2 backdrop-blur">
          {TABS.map((tab) => {
            const isActive = tab.id === activeTab
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`rounded-full border px-4 py-2 text-sm font-medium whitespace-nowrap transition duration-300 ${
                  isActive
                    ? "border-transparent bg-white text-slate-900 shadow-[0_6px_18px_rgba(255,255,255,0.2)]"
                    : "border-transparent bg-transparent text-slate-400 hover:-translate-y-0.5 hover:border-white/15 hover:bg-white/5 hover:text-slate-200"
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
