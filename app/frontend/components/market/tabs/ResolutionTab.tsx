import { useState } from "react"
import * as Tooltip from "@radix-ui/react-tooltip"
import type { ResolutionCriteria } from "@/types/market"

interface ResolutionTabProps {
  criteria: ResolutionCriteria | null
}

function AmbiguityChip({ level, tooltip }: { level: string | null; tooltip?: string | null }) {
  if (!level) return null
  const normalized = level.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())

  let borderColor = "border-l-emerald-500/60"
  let textColor = "text-emerald-400"
  const l = level.toLowerCase()
  if (l === "high") {
    borderColor = "border-l-red-500/60"
    textColor = "text-red-400"
  } else if (l === "moderate") {
    borderColor = "border-l-amber-500/60"
    textColor = "text-amber-400"
  } else if (l === "low") {
    borderColor = "border-l-sky-500/60"
    textColor = "text-sky-400"
  }

  const inner = (
    <div className={`flex items-center gap-2 border-l-[3px] ${borderColor} bg-white/4 py-1 pr-3 pl-2.5 ${tooltip ? "cursor-help" : ""}`}>
      <span className="font-mono text-[10px] font-medium tracking-wider text-slate-500">
        AMBIGUITY
      </span>
      <span className={`text-[13px] font-semibold ${textColor}`}>{normalized}</span>
    </div>
  )

  if (!tooltip) return inner

  return (
    <Tooltip.Provider>
      <Tooltip.Root delayDuration={200}>
        <Tooltip.Trigger asChild>{inner}</Tooltip.Trigger>
        <Tooltip.Portal>
          <Tooltip.Content
            side="bottom"
            sideOffset={6}
            className="z-50 max-w-xs rounded-md border border-white/10 bg-slate-900 px-3 py-2 text-xs leading-relaxed text-slate-300 shadow-lg"
          >
            {tooltip}
            <Tooltip.Arrow className="fill-slate-900" />
          </Tooltip.Content>
        </Tooltip.Portal>
      </Tooltip.Root>
    </Tooltip.Provider>
  )
}

export default function ResolutionTab({ criteria }: ResolutionTabProps) {
  const [expanded, setExpanded] = useState(false)
  const fullText = criteria?.criteriaText?.trim() || "No resolution criteria available."
  const isLong = fullText.length > 220

  return (
    <div className="space-y-4">
      {/* Criteria block */}
      <div className="rounded-md border border-white/8 bg-white/3">
        <div className="flex items-center gap-3 border-b border-white/6 px-5 py-2.5">
          <h3 className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
            Resolution Criteria
          </h3>
          <AmbiguityChip level={criteria?.ambiguityLevel ?? null} tooltip={criteria?.overallNote} />
        </div>
        <div className="px-5 py-4">
          <p
            className="whitespace-pre-wrap text-sm leading-relaxed text-slate-200"
            style={
              expanded
                ? undefined
                : {
                    display: "-webkit-box",
                    WebkitLineClamp: 4,
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
              className="mt-2 font-mono text-xs font-medium text-slate-500 transition hover:text-slate-200"
            >
              {expanded ? "[ collapse ]" : "[ expand ]"}
            </button>
          )}
        </div>
      </div>

      {/* Specs grid */}
      <div className="rounded-md border border-white/8 bg-white/3">
        <div className="border-b border-white/6 px-5 py-2.5">
          <h3 className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
            Specifications
          </h3>
        </div>
        <div className="grid divide-x divide-white/6 sm:grid-cols-2">
          <div className="space-y-1.5 px-5 py-4">
            <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
              Territorial Definitions
            </span>
            <p className="text-sm leading-relaxed text-slate-200">
              {criteria?.misinterpretations?.[0]?.description ||
                "Contained in the resolution criteria text."}
            </p>
          </div>
          <div className="space-y-1.5 px-5 py-4">
            <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
              Timeline Rules
            </span>
            <p className="text-sm leading-relaxed text-slate-200">
              Timeline constraints are described in the resolution criteria text.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
