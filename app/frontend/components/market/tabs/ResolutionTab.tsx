import { useMemo, useState } from "react"
import type { ResolutionCriteria } from "@/types/market"

interface ResolutionTabProps {
  criteria: ResolutionCriteria | null
}

function AmbiguityPill({ level }: { level: string | null }) {
  if (!level) return null
  const normalized = level.replace(/_/g, " ").toLowerCase()
  return (
    <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-sm text-white/60">
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
    <div className="space-y-4 rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="text-xl font-semibold text-white">Resolution</h3>
        <AmbiguityPill level={criteria?.ambiguityLevel ?? null} />
      </div>

      <div>
        <p className="mb-2 text-sm uppercase tracking-wide text-white/50">Resolution criteria</p>
        <p
          className="whitespace-pre-wrap text-base leading-relaxed text-white/80"
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
            className="mt-2 text-sm text-[#3B82F6] underline underline-offset-2 hover:text-[#60A5FA]"
          >
            {expanded ? "Show less" : "Show more"}
          </button>
        )}
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <p className="text-sm uppercase tracking-wide text-white/50">Territorial definitions</p>
          <p className="text-base text-white/75">
            {criteria?.misinterpretations?.[0]?.description || "Contained in the resolution criteria text."}
          </p>
        </div>
        <div className="space-y-2">
          <p className="text-sm uppercase tracking-wide text-white/50">Timeline rules</p>
          <p className="text-base text-white/75">
            Timeline constraints are described in the resolution criteria text.
          </p>
        </div>
      </div>
    </div>
  )
}
