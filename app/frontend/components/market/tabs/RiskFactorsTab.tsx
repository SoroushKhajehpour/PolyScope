import type { Factor } from "@/types/market"

interface RiskFactorsTabProps {
  factors: Factor[]
}

function normalizeScore(value: number): number {
  if (!Number.isFinite(value)) return 0
  return Math.max(0, Math.min(100, Math.round(value)))
}

function barColorClasses(score: number): { fill: string; glow: string; text: string } {
  if (score >= 70) {
    return {
      fill: "from-rose-400 to-rose-500",
      glow: "shadow-[0_0_16px_rgba(244,63,94,0.38)]",
      text: "text-rose-300",
    }
  }

  if (score >= 40) {
    return {
      fill: "from-amber-400 to-amber-500",
      glow: "shadow-[0_0_16px_rgba(245,158,11,0.4)]",
      text: "text-amber-300",
    }
  }

  return {
    fill: "from-emerald-400 to-emerald-500",
    glow: "shadow-[0_0_16px_rgba(16,185,129,0.45)]",
    text: "text-emerald-300",
  }
}

export default function RiskFactorsTab({ factors }: RiskFactorsTabProps) {
  if (factors.length === 0) {
    return (
      <div className="rounded-2xl border border-white/10 bg-[#0F1420]/75 p-6 backdrop-blur">
        <p className="text-base text-slate-400">No risk factors available.</p>
      </div>
    )
  }

  return (
    <div className="space-y-5 rounded-2xl border border-white/10 bg-[#0F1420]/75 p-6 backdrop-blur">
      <h3 className="text-xl font-bold text-white">Risk factors</h3>
      {factors.map((factor) => {
        const normalizedScore = normalizeScore(factor.score)
        const tone = barColorClasses(normalizedScore)

        return (
          <div
            key={factor.label}
            className="space-y-2 rounded-xl border border-white/10 bg-[#0B1120]/65 p-4 transition duration-300 hover:-translate-y-0.5 hover:border-white/20"
          >
            <div className="flex items-center justify-between gap-3">
              <p className="text-base font-medium text-slate-100">{factor.label}</p>
              <p className={`text-sm font-semibold ${tone.text}`}>{normalizedScore} / 100</p>
            </div>
            <div className="h-1 rounded-full bg-white/10">
              <div
                className={`animate-bar-breathe h-1 rounded-full bg-linear-to-r ${tone.fill} ${tone.glow}`}
                style={{ width: `${normalizedScore}%` }}
              />
            </div>
            {factor.explanation && (
              <p className="text-sm text-slate-400">{factor.explanation}</p>
            )}
          </div>
        )
      })}
    </div>
  )
}
