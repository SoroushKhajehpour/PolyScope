import { useMemo } from "react"
import { Link, router } from "@inertiajs/react"
import Layout from "@/components/layout/Layout"
import { useWatchlist } from "@/hooks/useWatchlist"
import { useMarketsDigest } from "@/hooks/useMarketsDigest"

function badgeFor(row: {
  rules_changed_after_score?: boolean
  score_label_outdated?: boolean
  missing?: boolean
}): { label: string; className: string } | null {
  if (row.missing) {
    return { label: "Not loaded", className: "border-slate-500/40 bg-slate-500/10 text-slate-300" }
  }
  if (row.rules_changed_after_score) {
    return { label: "Rules updated", className: "border-amber-500/40 bg-amber-500/10 text-amber-100" }
  }
  if (row.score_label_outdated) {
    return { label: "Score stale", className: "border-cyan-500/35 bg-cyan-500/10 text-cyan-100" }
  }
  return null
}

export default function Watchlist() {
  const { items, ids, remove } = useWatchlist()
  const { byEventId } = useMarketsDigest(ids, 60_000)

  const rows = useMemo(
    () =>
      items.map((item) => ({
        ...item,
        digest: byEventId[item.event_id],
      })),
    [items, byEventId]
  )

  return (
    <Layout centerContent>
      <div className="mx-auto w-full max-w-2xl py-10">
        <div className="mb-8 flex items-center justify-between gap-4">
          <Link
            href="/"
            className="text-[13px] font-medium text-slate-500 transition hover:text-slate-200"
          >
            ← Home
          </Link>
          <h1 className="text-lg font-semibold text-white">Watchlist</h1>
          <span className="w-16" aria-hidden />
        </div>

        {items.length === 0 ? (
          <p className="rounded-md border border-white/8 bg-white/3 px-4 py-6 text-sm text-slate-400">
            Save markets from search or a market page. Stored only in this browser (up to 50).
          </p>
        ) : (
          <ul className="divide-y divide-white/8 rounded-md border border-white/8 bg-white/3">
            {rows.map(({ event_id, title, digest }) => {
              const b = digest ? badgeFor(digest) : null
              return (
                <li key={event_id} className="flex items-center gap-3 px-4 py-3">
                  <button
                    type="button"
                    onClick={() => router.visit(`/markets/${event_id}`)}
                    className="min-w-0 flex-1 truncate text-left text-sm font-medium text-white transition hover:text-[#F5A623]"
                  >
                    {title}
                  </button>
                  <div className="flex shrink-0 items-center gap-2">
                    {b && (
                      <span
                        className={`rounded border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${b.className}`}
                      >
                        {b.label}
                      </span>
                    )}
                    <button
                      type="button"
                      onClick={() => remove(event_id)}
                      className="rounded border border-white/10 px-2 py-1 text-[11px] text-slate-400 transition hover:border-white/20 hover:text-slate-200"
                    >
                      Remove
                    </button>
                  </div>
                </li>
              )
            })}
          </ul>
        )}
      </div>
    </Layout>
  )
}
