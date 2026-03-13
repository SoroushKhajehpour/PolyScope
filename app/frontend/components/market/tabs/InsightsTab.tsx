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
    <div className="space-y-5 rounded-2xl border border-white/10 bg-[#0F1420]/75 p-7 backdrop-blur">
      <h3 className="text-xl font-bold text-white">Insights</h3>

      {cards.length > 0 ? (
        <div className="grid gap-3 sm:grid-cols-2">
          {cards.map((item, index) => (
            <div
              key={`${item}-${index}`}
              className="rounded-xl border border-white/10 bg-[#0A111F]/80 p-4 transition duration-300 hover:-translate-y-0.5 hover:border-white/20"
            >
              <p className="text-base text-slate-200">{item}</p>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-base text-slate-400">No insight cards available.</p>
      )}

      <div className="space-y-2">
        {liquidity?.explanation && (
          <p className="text-base text-slate-300">{liquidity.explanation}</p>
        )}
        {unavailableSources.length > 0 && (
          <p className="border-l-2 border-amber-400/50 pl-3 text-sm text-slate-400">
            Data limitations: some sources were unavailable ({unavailableSources.join(", ")}).
          </p>
        )}
      </div>
    </div>
  )
}
