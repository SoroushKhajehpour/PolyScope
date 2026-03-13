interface ScoreRingProps {
  score: number
}

export default function ScoreRing({ score }: ScoreRingProps) {
  return (
    <div className="relative h-[120px] w-[120px] shrink-0">
      <svg viewBox="0 0 36 36" className="h-full w-full -rotate-90">
        <circle cx="18" cy="18" r="15.9" fill="none" strokeWidth="3" className="stroke-white/10" />
        <circle
          cx="18"
          cy="18"
          r="15.9"
          fill="none"
          strokeWidth="3"
          strokeLinecap="round"
          className="stroke-[#2563EB]"
          strokeDasharray={`${score}, 100`}
        />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center text-3xl font-bold text-white">
        {score}
      </span>
    </div>
  )
}
