import type { Factor } from "@/types/market"

interface RiskFactorsTabProps {
  factors: Factor[]
}

export default function RiskFactorsTab({ factors }: RiskFactorsTabProps) {
  if (factors.length === 0) {
    return (
      <div className="rounded-xl border border-white/10 bg-[#0F1420] p-6">
        <p className="text-base text-white/60">No risk factors available.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4 rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <h3 className="text-xl font-semibold text-white">Risk factors</h3>
      {factors.map((factor) => (
        <div key={factor.label} className="space-y-2">
          <div className="flex items-center justify-between gap-3">
            <p className="text-base text-white/90">{factor.label}</p>
            <p className="text-sm text-white/70">{factor.score} / 100</p>
          </div>
          <div className="h-1.5 rounded-full bg-white/10">
            <div
              className="h-1.5 rounded-full bg-[#3B82F6]"
              style={{ width: `${Math.max(0, Math.min(100, factor.score))}%` }}
            />
          </div>
          {factor.explanation && (
            <p className="text-sm text-white/55">{factor.explanation}</p>
          )}
        </div>
      ))}
    </div>
  )
}
