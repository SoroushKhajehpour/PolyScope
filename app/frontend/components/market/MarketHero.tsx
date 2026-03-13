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
        <span className="inline-block rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-300/70">
          {market.category || "Uncategorized"}
        </span>
      </div>
      <div className="flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-sm text-slate-400">
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
    <section className="relative overflow-hidden rounded-2xl border border-white/10 bg-linear-to-br from-[#11192B]/90 via-[#0F1628]/85 to-[#0C1220]/90 p-7 backdrop-blur-xl sm:p-8">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(37,99,235,0.18),transparent_45%),radial-gradient(circle_at_85%_30%,rgba(56,189,248,0.12),transparent_40%)]" />
      <div className="relative flex flex-wrap items-center justify-center gap-7 text-center">
        <MarketMeta market={market} />

        {riskScore && (
          <div className="flex shrink-0 flex-col items-center gap-2">
            <ScoreRing score={riskScore.score} />
            {riskHeading && <p className="text-base font-semibold text-slate-200">{riskHeading}</p>}
          </div>
        )}
        {!riskScore && (
          <div className="rounded-2xl border border-white/10 bg-white/3 px-5 py-4 text-sm text-slate-400">
            Risk model pending
          </div>
        )}
      </div>
    </section>
  )
}
