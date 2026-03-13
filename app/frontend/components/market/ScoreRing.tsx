interface ScoreGaugeProps {
  score: number
  label?: string | null
  size?: "sm" | "md"
}

function clampScore(value: number): number {
  if (!Number.isFinite(value)) return 0
  return Math.max(0, Math.min(100, Math.round(value)))
}

function gaugeColor(score: number): string {
  if (score >= 70) return "#ef4444"
  if (score >= 40) return "#f59e0b"
  return "#10b981"
}

const ARC_RADIUS = 15.9
const CIRCUMFERENCE = 2 * Math.PI * ARC_RADIUS

export default function ScoreGauge({ score, label, size = "md" }: ScoreGaugeProps) {
  const clamped = clampScore(score)
  const color = gaugeColor(clamped)
  const dashOffset = CIRCUMFERENCE - (clamped / 100) * CIRCUMFERENCE

  const isSm = size === "sm"
  const boxSize = isSm ? "h-12 w-12" : "h-[72px] w-[72px]"
  const scoreText = isSm ? "text-sm" : "text-xl"

  return (
    <div className="flex flex-col items-center gap-1.5">
      <div className={`relative ${boxSize}`}>
        <svg viewBox="0 0 36 36" className="h-full w-full -rotate-90">
          <circle
            cx="18"
            cy="18"
            r={ARC_RADIUS}
            fill="none"
            strokeWidth={isSm ? "2.5" : "2"}
            className="stroke-white/6"
          />
          <circle
            cx="18"
            cy="18"
            r={ARC_RADIUS}
            fill="none"
            strokeWidth={isSm ? "2.5" : "2"}
            strokeLinecap="round"
            style={{
              stroke: color,
              strokeDasharray: `${CIRCUMFERENCE}`,
              strokeDashoffset: `${dashOffset}`,
              transition: "stroke-dashoffset 0.6s ease",
            }}
          />
        </svg>
        <span
          className={`absolute inset-0 flex items-center justify-center font-mono font-semibold tabular-nums tracking-tight text-white ${scoreText}`}
        >
          {clamped}
        </span>
      </div>
      {label && !isSm && (
        <span
          className="text-[10px] font-semibold uppercase tracking-widest"
          style={{ color }}
        >
          {label}
        </span>
      )}
    </div>
  )
}
