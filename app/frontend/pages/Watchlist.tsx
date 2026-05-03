import { useMemo } from "react"
import { Link, router } from "@inertiajs/react"
import Layout from "@/components/layout/Layout"
import { useWatchlist } from "@/hooks/useWatchlist"
import { useMarketsDigest } from "@/hooks/useMarketsDigest"
import { marketPath } from "@/lib/utils"

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
      <div className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6">
        <div className="mb-8 flex items-center justify-between gap-4">
          <Link
            href="/"
            className="text-[13px] font-medium text-slate-500 transition hover:text-slate-200"
          >
            ← Home
          </Link>
          <h1 className="text-lg font-semibold tracking-tight text-white">Watchlist</h1>
          <span className="w-14 sm:w-16" aria-hidden />
        </div>

        {items.length === 0 ? (
          <p className="rounded-lg border border-white/8 bg-white/[0.03] px-5 py-8 text-center text-sm leading-relaxed text-slate-400">
            Save markets from search or a market page. Stored only in this browser (up to 50).
          </p>
        ) : (
          <ul className="flex flex-col gap-3">
            {rows.map(({ event_id, title, event_image, digest }) => {
              const b = digest ? badgeFor(digest) : null
              return (
                <li
                  key={event_id}
                  className="flex items-stretch gap-4 rounded-lg border border-white/8 bg-white/[0.03] p-3 transition hover:border-white/12 sm:p-4"
                >
                  <button
                    type="button"
                    onClick={() => router.visit(marketPath(event_id))}
                    className="flex min-w-0 flex-1 items-center gap-4 text-left"
                  >
                    <div className="h-14 w-14 shrink-0 overflow-hidden rounded-lg border border-white/10 bg-white/5">
                      {event_image ? (
                        <img
                          src={event_image}
                          alt=""
                          className="h-full w-full object-cover"
                          loading="lazy"
                        />
                      ) : (
                        <div className="flex h-full w-full items-center justify-center text-[10px] font-medium uppercase tracking-wider text-slate-600">
                          —
                        </div>
                      )}
                    </div>
                    <div className="min-w-0 flex-1 py-0.5">
                      <p className="line-clamp-2 text-sm font-medium leading-snug text-white sm:text-[15px]">
                        {title}
                      </p>
                      <p className="mt-1 font-mono text-[11px] text-slate-500">{event_id}</p>
                    </div>
                  </button>
                  <div className="flex shrink-0 flex-col items-end justify-center gap-2 sm:flex-row sm:items-center">
                    {b && (
                      <span
                        className={`whitespace-nowrap rounded border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${b.className}`}
                      >
                        {b.label}
                      </span>
                    )}
                    <button
                      type="button"
                      onClick={() => remove(event_id)}
                      className="rounded-md border border-white/10 px-2.5 py-1.5 text-[11px] text-slate-400 transition hover:border-white/20 hover:text-slate-200"
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
