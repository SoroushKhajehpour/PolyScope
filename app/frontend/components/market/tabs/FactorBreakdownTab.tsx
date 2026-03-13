import type { ResolutionCriteria } from "@/types/market"

interface FactorBreakdownTabProps {
  criteria: ResolutionCriteria | null
}

const DIMENSION_LABELS: Record<string, string> = {
  temporal_precision: "Timeline",
  source_clarity: "Source",
  threshold_precision: "Threshold",
  linguistic_precision: "Language",
  completeness: "Completeness",
}

export default function FactorBreakdownTab({ criteria }: FactorBreakdownTabProps) {
  const dimensions = criteria?.dimensions

  if (!dimensions) {
    return (
      <div className="rounded-xl border border-white/10 bg-[#0F1420] p-6">
        <p className="text-base text-white/60">No factor breakdown available.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4 rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <h3 className="text-xl font-semibold text-white">Factor breakdown</h3>
      {Object.entries(DIMENSION_LABELS).map(([key, label]) => {
        const score = Math.max(0, Math.min(5, dimensions[key] ?? 0))
        return (
          <div key={key} className="space-y-2">
            <div className="flex items-center justify-between gap-3">
              <p className="text-base text-white/90">{label}</p>
              <p className="text-sm text-white/70">{score} / 5</p>
            </div>
            <div className="h-1.5 rounded-full bg-white/10">
              <div
                className="h-1.5 rounded-full bg-[#3B82F6]"
                style={{ width: `${(score / 5) * 100}%` }}
              />
            </div>
          </div>
        )
      })}
    </div>
  )
}
