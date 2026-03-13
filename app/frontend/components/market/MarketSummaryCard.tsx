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
    <section className="space-y-4 rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <h2 className="text-xl font-semibold text-white">Market summary</h2>

      <div className="flex flex-wrap gap-2 text-sm text-white/70">
        <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1">{riskLevel} risk</span>
        <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1">
          {confidenceLabel(riskScore.confidence_tier)}
        </span>
        <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1">
          {liquidityLabel(riskScore.liquidity?.label ?? null)}
        </span>
      </div>

      <p
        className="text-base leading-relaxed text-white/80"
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
