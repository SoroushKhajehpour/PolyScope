import type { FreshnessState } from "@/types/market"

function tone(f: FreshnessState | null): string {
  if (f === "blocking_stale") {
    return "border-rose-500/40 bg-rose-500/8 text-rose-100"
  }
  return "border-amber-500/35 bg-amber-500/8 text-amber-100"
}

export default function ScoreFreshnessBanner({
  freshness,
  message,
}: {
  freshness: FreshnessState | null
  message: string
}) {
  if (!freshness || freshness === "fresh" || !message) {
    return null
  }

  return (
    <div
      className={`rounded-md border px-4 py-3 text-sm leading-snug ${tone(freshness)}`}
      role="status"
    >
      {message}
    </div>
  )
}
