import { useState } from "react"
import type { ResolutionCriteria as ResolutionCriteriaType } from "@/types/market"

interface ResolutionCriteriaProps {
  criteria: ResolutionCriteriaType
}

function ambiguityBadge(level: string | null) {
  if (!level) return null
  const upper = level.toUpperCase()
  const labels: Record<string, string> = {
    NONE: "Clear",
    LOW: "Mostly Clear",
    MODERATE: "Some Ambiguity",
  }
  const label = labels[upper] ?? "Ambiguous"
  return (
    <span className="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-xs text-white/60">
      {label}
    </span>
  )
}

const DIM_LABELS: Record<string, string> = {
  temporal_precision: "Timeline",
  source_clarity: "Source",
  threshold_precision: "Threshold",
  linguistic_precision: "Language",
  completeness: "Completeness",
}


const TRUNCATE_THRESHOLD = 400

export default function ResolutionCriteria({ criteria }: ResolutionCriteriaProps) {
  const text = criteria.criteriaText || ""
  const isLong = text.length > TRUNCATE_THRESHOLD
  const [expanded, setExpanded] = useState(true)
  const displayText = expanded || !isLong ? text : `${text.slice(0, TRUNCATE_THRESHOLD)}...`

  if (!text && !criteria.hasAmbiguity) return null

  return (
    <div className="space-y-3 rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <div className="flex flex-wrap items-center gap-2">
        <p className="text-xs font-semibold uppercase tracking-wider text-white/50">Resolution criteria</p>
        {ambiguityBadge(criteria.ambiguityLevel)}
      </div>

      {text && (
        <blockquote className="whitespace-pre-wrap rounded border border-white/10 bg-white/5 p-4 text-sm leading-relaxed text-white/80">
          {displayText}
          {isLong && (
            <button
              type="button"
              onClick={() => setExpanded(!expanded)}
              className="ml-2 text-xs text-[#2563EB] underline hover:text-[#3B82F6]"
            >
              {expanded ? "show less" : "show more"}
            </button>
          )}
        </blockquote>
      )}

      {criteria.dimensions && (
        <div className="space-y-1.5">
          {Object.entries(DIM_LABELS).map(([key, label]) => {
            const ds = criteria.dimensions?.[key] ?? 0
            return (
              <div key={key} className="flex items-center gap-2">
                <span className="w-28 shrink-0 text-xs text-white/50">{label}</span>
                <div className="h-1.5 flex-1 rounded-full bg-white/10">
                  <div
                    className="h-1.5 rounded-full bg-[#2563EB]"
                    style={{ width: `${(ds / 5) * 100}%` }}
                  />
                </div>
                <span className="w-6 text-right text-xs text-white/70">{ds}/5</span>
              </div>
            )
          })}
        </div>
      )}

      {criteria.misinterpretations && criteria.misinterpretations.length > 0 && (
        <div className="space-y-2">
          {criteria.misinterpretations.map((item, i) => (
            <div key={i} className="rounded border border-white/10 bg-white/5 px-3 py-2">
              <p className="text-sm text-white/90">{item.issue}</p>
              <p className="mt-0.5 text-xs text-white/60">{item.description}</p>
              {item.affectedPhrase && (
                <p className="mt-0.5 text-xs italic text-white/50">&ldquo;{item.affectedPhrase}&rdquo;</p>
              )}
            </div>
          ))}
        </div>
      )}

      {criteria.overallNote && (
        <p className="text-sm text-white/70">{criteria.overallNote}</p>
      )}
    </div>
  )
}
