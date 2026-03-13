import { useMemo, useState } from "react"
import type { ResolutionCriteria } from "@/types/market"

interface ResolutionTabProps {
  criteria: ResolutionCriteria | null
}

function AmbiguityPill({ level }: { level: string | null }) {
  if (!level) return null
  const normalized = level.replace(/_/g, " ").toLowerCase()
  return (
    <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-sm text-slate-300">
      {normalized.replace(/^\w/, (c) => c.toUpperCase())}
    </span>
  )
}

export default function ResolutionTab({ criteria }: ResolutionTabProps) {
  const [expanded, setExpanded] = useState(false)

  const fullText = useMemo(() => {
    if (!criteria?.criteriaText?.trim()) return "No resolution criteria available."
    return criteria.criteriaText
  }, [criteria])

  const isLong = fullText.length > 220

  return (
    <div className="space-y-5 rounded-2xl border border-white/10 bg-[#0F1420]/75 p-7 backdrop-blur">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="text-xl font-bold text-white">Resolution</h3>
        <AmbiguityPill level={criteria?.ambiguityLevel ?? null} />
      </div>

      <div>
        <p className="mb-2 text-sm font-medium uppercase tracking-wide text-slate-400">Resolution criteria</p>
        <p
          className="whitespace-pre-wrap text-base leading-relaxed text-slate-300"
          style={
            expanded
              ? undefined
              : {
                  display: "-webkit-box",
                  WebkitLineClamp: 3,
                  WebkitBoxOrient: "vertical",
                  overflow: "hidden",
                }
          }
        >
          {fullText}
        </p>
        {isLong && (
          <button
            type="button"
            onClick={() => setExpanded((prev) => !prev)}
            className="mt-2 text-sm text-blue-400 underline underline-offset-2 transition hover:text-blue-300"
          >
            {expanded ? "Show less" : "Show more"}
          </button>
        )}
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2 rounded-xl border border-white/10 bg-[#0A111F]/80 p-4 transition duration-300 hover:-translate-y-0.5 hover:border-white/20">
          <p className="text-sm font-medium uppercase tracking-wide text-slate-400">Territorial definitions</p>
          <p className="text-base text-slate-300">
            {criteria?.misinterpretations?.[0]?.description || "Contained in the resolution criteria text."}
          </p>
        </div>
        <div className="space-y-2 rounded-xl border border-white/10 bg-[#0A111F]/80 p-4 transition duration-300 hover:-translate-y-0.5 hover:border-white/20">
          <p className="text-sm font-medium uppercase tracking-wide text-slate-400">Timeline rules</p>
          <p className="text-base text-slate-300">
            Timeline constraints are described in the resolution criteria text.
          </p>
        </div>
      </div>
    </div>
  )
}
