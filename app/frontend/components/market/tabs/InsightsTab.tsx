import type { LiquidityNote } from "@/types/market"

interface InsightsTabProps {
  topDrivers: string[]
  whyNotHigherRisk: string[]
  liquidity: LiquidityNote | null
  unavailableSources: string[]
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
    </div>
  )
}
