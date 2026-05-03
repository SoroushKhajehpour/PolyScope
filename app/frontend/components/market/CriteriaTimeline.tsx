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

export default function CriteriaTimeline({ entries }: { entries: CriteriaTimelineEntry[] }) {
  const [openId, setOpenId] = useState<string | null>(null)

  if (entries.length === 0) {
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
          Criteria timeline
        </span>
        <p className="mt-1 text-[12px] text-slate-500">
          Text changes and detected clarifications, newest first. Not a trading signal.
        </p>
      </div>
      <ul className="divide-y divide-white/6">
        {entries.map((e) => {
          const isOpen = openId === e.id
          return (
            <li key={e.id}>
              <button
                type="button"
                onClick={() => setOpenId(isOpen ? null : e.id)}
                className="flex w-full items-start gap-3 px-4 py-3 text-left transition hover:bg-white/[0.04]"
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
                <span className="shrink-0 text-slate-500">{isOpen ? "−" : "+"}</span>
              </button>
              {isOpen && e.type === "clarification" && e.diff_html && (
                <div
                  className="border-t border-white/6 bg-black/20 px-4 py-3 font-mono text-[12px] leading-relaxed text-slate-300 [&_ins]:bg-emerald-500/20 [&_del]:bg-rose-500/25"
                  dangerouslySetInnerHTML={{ __html: e.diff_html }}
                />
              )}
              {isOpen && e.type === "snapshot" && (
                <div className="border-t border-white/6 bg-black/20 px-4 py-3 text-[13px] text-slate-300">
                  Snapshot stored when wording moved enough to matter for drift tracking.
                </div>
              )}
            </li>
          )
        })}
      </ul>
    </div>
  )
}
