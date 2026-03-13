import type { RiskScoreProps } from "@/types/market"

interface MarketSummaryCardProps {
  riskScore: RiskScoreProps
}

function confidenceLabel(tier: string | null): string {
  if (!tier) return "Unknown confidence"
  const normalized = tier.replace(/_/g, " ").toLowerCase()
  return `${normalized.replace(/^\w/, (c) => c.toUpperCase())} confidence`
}

function liquidityLabel(label: string | null): string {
  if (!label) return "Unknown liquidity"
  const normalized = label.replace(/_/g, " ").toLowerCase()
  return `${normalized.replace(/^\w/, (c) => c.toUpperCase())} liquidity`
}

export default function MarketSummaryCard({ riskScore }: MarketSummaryCardProps) {
  const riskLevel = riskScore.level
    .replace(/_/g, " ")
    .replace(/^\w/, (c) => c.toUpperCase())

  const summaryText = riskScore.summary || riskScore.confidence_note || "No summary available."

  return (
    <section className="space-y-4 rounded-2xl border border-white/10 bg-[#0F1420]/75 p-7 backdrop-blur">
      <h2 className="text-2xl font-bold text-white">Market summary</h2>

      <div className="flex flex-wrap gap-2 text-sm text-slate-300">
        <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5">{riskLevel} risk</span>
        <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5">
          {confidenceLabel(riskScore.confidence_tier)}
        </span>
        <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5">
          {liquidityLabel(riskScore.liquidity?.label ?? null)}
        </span>
      </div>

      <p
        className="text-base leading-relaxed text-slate-300"
        style={{
          display: "-webkit-box",
          WebkitLineClamp: 3,
          WebkitBoxOrient: "vertical",
          overflow: "hidden",
        }}
      >
        {summaryText}
      </p>
    </section>
  )
}
