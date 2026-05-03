import type { LiquidityNote, SimilarResolvedMarketProps } from "@/types/market"

interface InsightsTabProps {
  topDrivers: string[]
  whyNotHigherRisk: string[]
  liquidity: LiquidityNote | null
  unavailableSources: string[]
  similarResolvedMarkets: SimilarResolvedMarketProps[]
}

function SectionCard({
  title,
  children,
}: {
  title: string
  children: React.ReactNode
}) {
  return (
    <div className="rounded-md border border-white/8 bg-white/3">
      <div className="border-b border-white/6 px-5 py-2.5">
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
          {title}
        </span>
      </div>
      {children}
    </div>
  )
}

export default function InsightsTab({
  topDrivers,
  whyNotHigherRisk,
  liquidity,
  unavailableSources,
  similarResolvedMarkets,
}: InsightsTabProps) {
  const drivers = topDrivers.length > 0 ? topDrivers : null
  const mitigators = whyNotHigherRisk.length > 0 ? whyNotHigherRisk : null

  return (
    <div className="space-y-4">
      {/* Drivers + Mitigators grid */}
      <div className="grid gap-4 sm:grid-cols-2">
        <SectionCard title="Risk Drivers">
          <ul className="divide-y divide-white/6">
            {drivers ? (
              drivers.map((item, i) => (
                <li key={i} className="flex items-start gap-3 px-5 py-3">
                  <span className="mt-[7px] block h-1.5 w-1.5 shrink-0 rounded-full bg-red-500/70" />
                  <span className="text-sm leading-relaxed text-slate-200">{item}</span>
                </li>
              ))
            ) : (
              <li className="px-5 py-3 text-sm text-slate-600">None identified</li>
            )}
          </ul>
        </SectionCard>

        <SectionCard title="Mitigating Factors">
          <ul className="divide-y divide-white/6">
            {mitigators ? (
              mitigators.map((item, i) => (
                <li key={i} className="flex items-start gap-3 px-5 py-3">
                  <span className="mt-[7px] block h-1.5 w-1.5 shrink-0 rounded-full bg-emerald-500/70" />
                  <span className="text-sm leading-relaxed text-slate-200">{item}</span>
                </li>
              ))
            ) : (
              <li className="px-5 py-3 text-sm text-slate-600">None identified</li>
            )}
          </ul>
        </SectionCard>
      </div>

      {/* Liquidity + data limitations */}
      {(liquidity?.explanation || unavailableSources.length > 0) && (
        <div className="rounded-md border border-white/8 bg-white/3 px-5 py-4">
          {liquidity?.explanation && (
            <p className="text-sm leading-relaxed text-slate-200">
              {liquidity.explanation}
            </p>
          )}
          {unavailableSources.length > 0 && (
            <p className="mt-3 border-l-[3px] border-amber-500/50 pl-3 font-mono text-[12px] text-slate-500">
              DATA_LIMITATIONS: sources unavailable — {unavailableSources.join(", ")}
            </p>
          )}
        </div>
      )}

      {similarResolvedMarkets.length > 0 && (
        <SectionCard title="Comparable markets (pattern similarity)">
          <p className="border-b border-white/6 px-5 py-3 text-[12px] leading-relaxed text-slate-400">
            Embedding-matched markets in the same category—not trading advice and not a price prediction.
          </p>
          <ul className="divide-y divide-white/6">
            {similarResolvedMarkets.map((m) => (
              <li key={m.event_id ?? m.event_question} className="px-5 py-3">
                <p className="text-sm font-medium text-slate-100">{m.event_question}</p>
                <div className="mt-1 flex flex-wrap gap-x-4 gap-y-1 font-mono text-[11px] text-slate-500">
                  {m.similarity != null && (
                    <span>Similarity {(m.similarity * 100).toFixed(1)}%</span>
                  )}
                  {m.status && <span>Status {m.status}</span>}
                  {m.dispute_hint && <span>{m.dispute_hint}</span>}
                </div>
              </li>
            ))}
          </ul>
        </SectionCard>
      )}
    </div>
  )
}
