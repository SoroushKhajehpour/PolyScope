import type { MarketProps, RiskScoreProps } from "@/types/market"
import { formatScoreAsOf, formatVolume } from "@/lib/utils"
import { useWatchlist } from "@/hooks/useWatchlist"
import ScoreGauge from "./ScoreRing"

interface MarketHeroProps {
  market: MarketProps
  riskScore?: RiskScoreProps | null
}

function MetaField({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
        {label}
      </span>
      <span className="font-mono text-sm font-medium tabular-nums text-slate-50">
        {value}
      </span>
    </div>
  )
}

export default function MarketHero({ market, riskScore }: MarketHeroProps) {
  const { toggle, isWatched } = useWatchlist()

  const endDateStr = market.end_date
    ? new Date(market.end_date).toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
      })
    : null

  const riskLabel = riskScore?.level
    ? riskScore.level.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())
    : null

  return (
    <section className="rounded-md border border-white/8 bg-white/3">
      {/* Top row: identity + gauge */}
      <div className="flex items-start justify-between gap-6 p-6 sm:p-7">
        <div className="flex min-w-0 flex-1 items-start gap-4">
          <div className="h-20 w-20 shrink-0 overflow-hidden rounded-lg border border-white/8 bg-white/4">
            {market.event_image ? (
              <img
                src={market.event_image}
                alt=""
                className="h-full w-full object-cover"
                loading="lazy"
              />
            ) : (
              <div className="flex h-full w-full items-center justify-center text-[9px] font-medium uppercase tracking-wider text-slate-600">
                —
              </div>
            )}
          </div>
          <div className="min-w-0 space-y-2.5">
            <h1 className="text-lg font-semibold leading-snug tracking-[-0.01em] text-white sm:text-xl">
              {market.event_question}
            </h1>
            <span className="inline-block border border-white/8 bg-white/4 px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-500">
              {market.category || "Uncategorized"}
            </span>
          </div>
        </div>

        <button
          type="button"
          onClick={() => toggle(market.event_id, market.event_question, market.event_image)}
          className={`shrink-0 rounded-md border px-2.5 py-1.5 text-[11px] font-semibold uppercase tracking-[0.12em] transition ${
            isWatched(market.event_id)
              ? "border-cyan-500/40 bg-cyan-500/15 text-cyan-200"
              : "border-white/12 bg-white/5 text-slate-400 hover:border-white/20 hover:text-slate-200"
          }`}
          aria-pressed={isWatched(market.event_id)}
        >
          {isWatched(market.event_id) ? "Watching" : "Watch"}
        </button>

        {/* Right: risk gauge */}
        <div className="hidden shrink-0 sm:block">
          {riskScore ? (
            <ScoreGauge score={riskScore.score} label={riskLabel} />
          ) : (
            <div className="flex h-[72px] w-[72px] items-center justify-center rounded border border-white/8 bg-white/3">
              <span className="text-[10px] font-medium uppercase tracking-wider text-slate-600">
                N/A
              </span>
            </div>
          )}
        </div>
      </div>

      <div className="h-px bg-white/6" />

      {/* Bottom row: metadata ribbon */}
      <div className="flex items-center gap-8 px-6 py-4 sm:px-7">
        {riskScore && (
          <div className="sm:hidden">
            <ScoreGauge score={riskScore.score} label={riskLabel} size="sm" />
          </div>
        )}
        {endDateStr && <MetaField label="Expires" value={endDateStr} />}
        {market.volume != null && (
          <MetaField label="Volume" value={formatVolume(market.volume)} />
        )}
        {riskScore?.computed_at && (
          <MetaField label="Score as of" value={formatScoreAsOf(riskScore.computed_at)} />
        )}
        {riskScore?.confidence_tier && (
          <MetaField
            label="Confidence"
            value={riskScore.confidence_tier.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())}
          />
        )}
      </div>
    </section>
  )
}
