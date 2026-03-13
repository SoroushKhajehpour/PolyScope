import type { Factor } from "@/types/market"

interface RiskFactorsTabProps {
  factors: Factor[]
}

function clamp(value: number): number {
  if (!Number.isFinite(value)) return 0
  return Math.max(0, Math.min(100, Math.round(value)))
}

function barColor(score: number): string {
  if (score >= 70) return "bg-amber-500/80"
  if (score >= 40) return "bg-slate-400/50"
  return "bg-emerald-500/60"
}

function scoreTextColor(score: number): string {
  if (score >= 70) return "text-amber-400"
  if (score >= 40) return "text-slate-400"
  return "text-emerald-400"
}

export default function RiskFactorsTab({ factors }: RiskFactorsTabProps) {
  if (factors.length === 0) {
    return (
      <div className="rounded-md border border-white/8 bg-white/3 p-5">
        <p className="text-sm text-slate-500">No risk factors available.</p>
      </div>
    )
  }

  return (
    <div className="rounded-md border border-white/8 bg-white/3">
      {/* Header row */}
      <div className="grid grid-cols-[1fr_60px] items-center gap-4 border-b border-white/6 px-5 py-2.5 sm:grid-cols-[160px_1fr_60px]">
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
          Factor
        </span>
        <span className="hidden text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500 sm:block">
          Detail
        </span>
        <span className="text-right text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
          Score
        </span>
      </div>

      {/* Factor rows */}
      {factors.map((factor, i) => {
        const score = clamp(factor.score)
        const isLast = i === factors.length - 1

        return (
          <div
            key={factor.label}
            className={`grid grid-cols-[1fr_60px] items-start gap-4 px-5 py-3.5 sm:grid-cols-[160px_1fr_60px] ${
              !isLast ? "border-b border-white/6" : ""
            }`}
          >
            {/* Label + bar */}
            <div className="space-y-2">
              <span className="text-sm font-semibold text-white">
                {factor.label}
              </span>
              <div className="h-[2px] w-full bg-white/6">
                <div
                  className={`h-[2px] ${barColor(score)}`}
                  style={{ width: `${score}%` }}
                />
              </div>
            </div>

            {/* Explanation */}
            {factor.explanation && (
              <p className="hidden pt-0.5 text-[13px] leading-relaxed text-slate-300 sm:block">
                {factor.explanation}
              </p>
            )}

            {/* Score */}
            <span className="text-right font-mono text-sm tabular-nums">
              <span className={scoreTextColor(score)}>{score}</span>
              <span className="text-slate-600">/100</span>
            </span>
          </div>
        )
      })}
    </div>
  )
}
