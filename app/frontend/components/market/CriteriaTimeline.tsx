import { useState } from "react"
import type { CriteriaTimelineEntry } from "@/types/market"

function formatAt(iso: string | null): string {
  if (!iso) return "—"
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  })
}

function labelFor(e: CriteriaTimelineEntry): string {
  if (e.type === "snapshot") {
    return e.change_type ? `Description snapshot (${e.change_type})` : "Description snapshot"
  }
  return "Clarification"
}

function entryFullText(e: CriteriaTimelineEntry): string {
  const full = (e.full_text ?? e.fullText ?? "").toString().trim()
  if (full.length > 0) return full
  return (e.summary ?? "").toString().trim()
}

export default function CriteriaTimeline({
  entries = [],
}: {
  entries?: CriteriaTimelineEntry[] | null
}) {
  const [openId, setOpenId] = useState<string | null>(null)
  const safe = entries ?? []

  if (safe.length === 0) {
    return (
      <div className="rounded-md border border-white/8 bg-white/3 px-4 py-3 text-sm text-slate-500">
        No stored criteria changes yet. Snapshots and clarifications appear here when we detect
        updates.
      </div>
    )
  }

  return (
    <div className="rounded-md border border-white/8 bg-white/3">
      <div className="border-b border-white/6 px-4 py-2.5">
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
          Criteria change timeline
        </span>
        <p className="mt-1 text-[12px] leading-snug text-slate-500">
          Chronological history of updates to the published resolution text (newest at the top).
          Each dot is one detected change. Expand a row to read the full wording from that moment.
          Not a trading signal.
        </p>
      </div>
      <ul className="divide-y divide-white/6">
        {safe.map((e, index) => {
          const isOpen = openId === e.id
          const isLast = index === safe.length - 1
          return (
            <li key={e.id} className="flex gap-0">
              {/* Timeline: dot + stem so reads as one history thread */}
              <div
                className="flex w-10 shrink-0 flex-col items-center bg-black/6 py-3"
                aria-hidden
              >
                <div
                  className={`mt-1 h-2.5 w-2.5 shrink-0 rounded-full border-2 border-slate-950 shadow-sm ${
                    e.type === "clarification" ? "bg-violet-400/85" : "bg-cyan-400/85"
                  }`}
                />
                {!isLast ? (
                  <div className="mt-1 w-px flex-1 min-h-5 bg-linear-to-b from-white/20 to-white/5" />
                ) : null}
              </div>
              <div className="min-w-0 flex-1">
                <button
                  type="button"
                  onClick={() => setOpenId(isOpen ? null : e.id)}
                  aria-expanded={isOpen}
                  className="flex w-full items-start gap-2 px-3 py-3 pr-4 text-left transition hover:bg-white/4 sm:gap-3 sm:pr-5"
                >
                  <span className="mt-0.5 shrink-0 font-mono text-[11px] tabular-nums text-slate-500">
                    {formatAt(e.at)}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                      {labelFor(e)}
                    </span>
                    <span className="mt-0.5 block text-sm text-slate-200">{e.summary}</span>
                  </span>
                  <span className="shrink-0 self-start pt-0.5 font-mono text-sm text-slate-400">
                    {isOpen ? "−" : "+"}
                  </span>
                </button>
                {isOpen && (
                  <div className="border-t border-white/6 bg-black/20 px-3 py-3 pr-4 sm:px-4">
                    <p className="whitespace-pre-wrap wrap-break-word text-[13px] leading-relaxed text-slate-200">
                      {entryFullText(e)}
                    </p>
                  </div>
                )}
              </div>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
