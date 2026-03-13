interface ScoreRingProps {
  score: number
}

function clampScore(value: number): number {
  if (!Number.isFinite(value)) return 0
  return Math.max(0, Math.min(100, Math.round(value)))
}

function gaugeColor(score: number): string {
  if (score >= 70) return "#FB7185"
  if (score >= 40) return "#F59E0B"
  return "#10B981"
}

export default function ScoreRing({ score }: ScoreRingProps) {
  const normalizedScore = clampScore(score)
  const stroke = gaugeColor(normalizedScore)

  return (
    <div className="relative h-[114px] w-[114px] shrink-0">
      <div
        className="absolute inset-1 rounded-full blur-xl"
        style={{ background: `radial-gradient(circle, ${stroke}40 0%, transparent 70%)` }}
      />
      <svg viewBox="0 0 36 36" className="h-full w-full -rotate-90">
        <circle cx="18" cy="18" r="15.9" fill="none" strokeWidth="4.25" className="stroke-white/10" />
        <circle
          cx="18"
          cy="18"
          r="15.9"
          fill="none"
          strokeWidth="4.25"
          strokeLinecap="round"
          style={{ stroke }}
          strokeDasharray={`${normalizedScore}, 100`}
        />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center text-2xl font-black tracking-tight text-white">
        {normalizedScore}
      </span>
    </div>
  )
}
