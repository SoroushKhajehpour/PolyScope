import type { MarketProps } from "@/types/market"
import type { RiskScoreProps } from "@/types/market"
import { formatVolume } from "@/lib/utils"
import ScoreRing from "./ScoreRing"

interface MarketHeroProps {
  market: MarketProps
  riskScore?: RiskScoreProps | null
}

function MarketMeta({ market }: { market: MarketProps }) {
  const endDateStr = market.end_date
    ? new Date(market.end_date).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })
    : null

  return (
    <div className="min-w-0 flex-1 space-y-4">
      <div className="h-[72px] w-[72px] shrink-0 overflow-hidden rounded-full border border-white/10 bg-[#1f2937] md:hidden">
        {market.event_image ? (
          <img
            src={market.event_image}
            alt=""
            className="h-full w-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-sm text-white/50">
            No img
          </div>
        )}
      </div>
      <div>
        <span className="inline-block rounded bg-white/5 px-2 py-0.5 text-sm font-medium uppercase tracking-wide text-white/50">
          {market.category || "Uncategorized"}
        </span>
        <h1 className="mt-2 text-3xl font-medium leading-tight text-white">
          {market.event_question || `Market #${market.event_id}`}
        </h1>
      </div>
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-white/50">
        {endDateStr && <span>Ends {endDateStr}</span>}
        {endDateStr && market.volume != null && <span aria-hidden>·</span>}
        {market.volume != null && <span>{formatVolume(market.volume)} volume</span>}
      </div>
    </div>
  )
}

export default function MarketHero({ market, riskScore }: MarketHeroProps) {
  const riskHeading = riskScore?.level
    ? `${riskScore.level.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())} Risk`
    : null

  return (
    <div className="rounded-xl border border-white/10 bg-[#0F1420] p-6">
      <div className="flex flex-col gap-6 md:flex-row md:items-start">
        <div className="hidden h-[72px] w-[72px] shrink-0 overflow-hidden rounded-full border border-white/10 bg-[#1f2937] md:flex md:items-center md:justify-center">
          {market.event_image ? (
            <img
              src={market.event_image}
              alt=""
              className="h-full w-full object-cover"
              loading="lazy"
            />
          ) : (
            <div className="text-sm text-white/50">
              No img
            </div>
          )}
        </div>

        <MarketMeta market={market} />

        {riskScore && (
          <div className="flex shrink-0 flex-col items-center gap-2 self-start md:ml-2">
            <ScoreRing score={riskScore.score} />
            {riskHeading && <p className="text-base font-medium text-white/80">{riskHeading}</p>}
          </div>
        )}
      </div>
    </div>
  )
}
