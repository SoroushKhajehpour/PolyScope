import type { Factor } from "@/types/market"

interface FactorBreakdownProps {
  factors: Factor[]
}

export default function FactorBreakdown({ factors }: FactorBreakdownProps) {
  if (factors.length === 0) return null

  return (
    <div className="rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <p className="mb-4 text-xs font-semibold uppercase tracking-wider text-white/50">
        Risk factors
      </p>
      <div className="space-y-4">
        {factors.map((factor) => (
          <div key={factor.label}>
            <div className="flex items-center justify-between text-sm">
              <span className="font-sans text-white/90">{factor.label}</span>
              <span className="font-sans font-medium text-white/80">
                {factor.score} / 100
              </span>
            </div>
            <div className="mt-1.5 h-1.5 rounded-full bg-white/10">
              <div
                className="h-1.5 rounded-full bg-[#2563EB]"
                style={{ width: `${Math.min(Math.max(factor.score, 0), 100)}%` }}
              />
            </div>
            {factor.explanation && (
              <p className="mt-1.5 text-[13px] leading-snug text-white/50">
                {factor.explanation}
              </p>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
