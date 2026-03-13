import type { MarketProps } from "@/types/market"
import { formatVolume } from "@/lib/utils"

interface MarketHeroProps {
  market: MarketProps
}

export default function MarketHero({ market }: MarketHeroProps) {
  const endDateStr = market.end_date
    ? new Date(market.end_date).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })
    : null

  return (
    <div className="rounded-xl border border-white/10 bg-[#0F1420] px-6 py-8">
      <div className="flex items-start gap-4">
        <div className="h-[72px] w-[72px] shrink-0 overflow-hidden rounded-full border border-white/10 bg-[#1f2937]">
          {market.event_image ? (
            <img
              src={market.event_image}
              alt=""
              className="h-full w-full object-cover"
              loading="lazy"
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-xs text-white/50">
              No img
            </div>
          )}
        </div>
        <div className="min-w-0 flex-1">
          <span className="inline-block rounded bg-white/5 px-2 py-0.5 text-xs font-medium uppercase tracking-wide text-white/50">
            {market.category || "Uncategorized"}
          </span>
          <h1 className="mt-2 text-[28px] font-medium leading-snug text-white">
            {market.event_question || `Market #${market.event_id}`}
          </h1>
          <div className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-white/50">
            {endDateStr && <span>Ends {endDateStr}</span>}
            {endDateStr && market.volume != null && <span aria-hidden>·</span>}
            {market.volume != null && <span>{formatVolume(market.volume)} vol</span>}
          </div>
        </div>
      </div>
    </div>
  )
}
