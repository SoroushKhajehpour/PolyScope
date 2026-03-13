import type { LiquidityNote } from "@/types/market"

interface InsightsTabProps {
  topDrivers: string[]
  whyNotHigherRisk: string[]
  liquidity: LiquidityNote | null
  unavailableSources: string[]
}

export default function InsightsTab({
  topDrivers,
  whyNotHigherRisk,
  liquidity,
  unavailableSources,
}: InsightsTabProps) {
  const cards = [...topDrivers, ...whyNotHigherRisk]

  return (
    <div className="space-y-4 rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <h3 className="text-xl font-semibold text-white">Insights</h3>

      {cards.length > 0 ? (
        <div className="grid gap-3 sm:grid-cols-2">
          {cards.map((item, index) => (
            <div key={`${item}-${index}`} className="rounded-xl border border-white/10 bg-white/5 p-4">
              <p className="text-base text-white/85">{item}</p>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-base text-white/60">No insight cards available.</p>
      )}

      <div className="space-y-2">
        {liquidity?.explanation && (
          <p className="text-base text-white/70">{liquidity.explanation}</p>
        )}
        {unavailableSources.length > 0 && (
          <p className="border-l-2 border-amber-500/50 pl-3 text-sm text-white/55">
            Data limitations: some sources were unavailable ({unavailableSources.join(", ")}).
          </p>
        )}
      </div>
    </div>
  )
}
