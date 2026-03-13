import type { LiquidityNote } from "@/types/market"

const PILL_CLASS =
  "rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-xs text-white/60"

interface InsightsPanelProps {
  topDrivers: string[]
  whyNotHigherRisk: string[]
  liquidity: LiquidityNote | null
  unavailableSources: string[]
}

export default function InsightsPanel({
  topDrivers,
  whyNotHigherRisk,
  liquidity,
  unavailableSources,
}: InsightsPanelProps) {
  const hasTags = topDrivers.length > 0 || whyNotHigherRisk.length > 0
  const hasPlainText = !!liquidity?.explanation || unavailableSources.length > 0

  if (!hasTags && !hasPlainText) return null

  return (
    <div className="rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <p className="mb-4 text-xs font-semibold uppercase tracking-wider text-white/50">
        Insights
      </p>

      {hasTags && (
        <div className="flex flex-wrap gap-2">
          {topDrivers.map((d, i) => (
            <span key={`driver-${i}`} className={PILL_CLASS}>
              {d}
            </span>
          ))}
          {whyNotHigherRisk.map((r, i) => (
            <span key={`why-${i}`} className={PILL_CLASS}>
              {r}
            </span>
          ))}
        </div>
      )}

      {hasPlainText && (
        <div className="mt-4 space-y-2">
          {liquidity?.explanation && (
            <p className="text-[13px] leading-relaxed text-white/50">
              {liquidity.explanation}
            </p>
          )}
          {unavailableSources.length > 0 && (
            <p className="border-l-2 border-amber-500/50 pl-3 text-[13px] text-white/50">
              Data availability: some sources were unavailable ({unavailableSources.join(", ")}).
            </p>
          )}
        </div>
      )}
    </div>
  )
}
