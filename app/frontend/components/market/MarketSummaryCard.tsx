import * as Tooltip from "@radix-ui/react-tooltip"
import type { RiskScoreProps } from "@/types/market"

interface MarketSummaryCardProps {
  riskScore: RiskScoreProps
}

type ChipAccent = "emerald" | "amber" | "red"

function chipAccent(level: string): ChipAccent {
  const l = level.toLowerCase()
  if (l === "high" || l === "very_high" || l === "critical") return "red"
  if (l === "medium" || l === "moderate") return "amber"
  return "emerald"
}

const ACCENT_STYLES: Record<ChipAccent, { border: string; text: string }> = {
  emerald: { border: "border-l-emerald-500/60", text: "text-emerald-400" },
  amber: { border: "border-l-amber-500/60", text: "text-amber-400" },
  red: { border: "border-l-red-500/60", text: "text-red-400" },
}

function formatValue(value: string | null, fallback: string): string {
  if (!value) return fallback
  const formatted = value.replace(/_/g, " ").toLowerCase().replace(/^\w/, (c) => c.toUpperCase())
  return formatted
}

function stripRedundantWord(word: string, value: string): string {
  const re = new RegExp(`\\b${word}\\b`, "i")
  return value.replace(re, "").replace(/\s+/g, " ").trim().replace(/^\w/, (c) => c.toUpperCase())
}

function confidenceAccent(level: string): ChipAccent {
  const l = level.toLowerCase()
  if (l.includes("high")) return "emerald"
  if (l.includes("medium") || l.includes("moderate")) return "amber"
  if (l.includes("low")) return "red"
  return "amber"
}

function liquidityAccent(level: string): ChipAccent {
  const l = level.toLowerCase()
  if (l.includes("high")) return "emerald"
  if (l.includes("moderate") || l.includes("medium")) return "amber"
  if (l.includes("low")) return "red"
  return "amber"
}

function Chip({ tag, value, accent, tooltip }: {
  tag: string
  value: string
  accent: ChipAccent
  tooltip?: string | null
}) {
  const styles = ACCENT_STYLES[accent]
  const inner = (
    <div
      className={`flex items-baseline gap-2 border-l-[3px] ${styles.border} bg-white/4 py-1.5 pr-3.5 pl-3 ${tooltip ? "cursor-help" : ""}`}
    >
      <span className="font-mono text-[10px] font-medium tracking-wider text-slate-500">
        {tag}
      </span>
      <span className={`text-[13px] font-semibold ${styles.text}`}>
        {value}
      </span>
    </div>
  )

  if (!tooltip) return inner

  return (
    <Tooltip.Root delayDuration={200}>
      <Tooltip.Trigger asChild>{inner}</Tooltip.Trigger>
      <Tooltip.Portal>
        <Tooltip.Content
          side="bottom"
          sideOffset={6}
          className="z-50 max-w-xs rounded-md border border-white/10 bg-slate-900 px-3 py-2 text-xs leading-relaxed text-slate-300 shadow-lg"
        >
          {tooltip}
          <Tooltip.Arrow className="fill-slate-900" />
        </Tooltip.Content>
      </Tooltip.Portal>
    </Tooltip.Root>
  )
}

export default function MarketSummaryCard({ riskScore }: MarketSummaryCardProps) {
  const riskLevel = formatValue(riskScore.level, "Unknown")
  const confidence = formatValue(riskScore.confidence_tier, "Unknown")
  const rawLiquidity = formatValue(riskScore.liquidity?.label ?? null, "Unknown")
  const liquidity = stripRedundantWord("liquidity", rawLiquidity)
  const summaryText = riskScore.summary || riskScore.confidence_note || "No summary available."

  const riskAccent = chipAccent(riskScore.level)
  const confAccent = confidenceAccent(riskScore.confidence_tier ?? "unknown")
  const liqAccent = liquidityAccent(riskScore.liquidity?.label ?? "unknown")

  return (
    <section className="rounded-md border border-white/8 bg-white/3">
      <div className="border-b border-white/6 px-5 py-3">
        <h2 className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
          Market Summary
        </h2>
      </div>

      <div className="p-5">
        <Tooltip.Provider>
          <div className="flex flex-wrap items-stretch gap-2">
            <Chip tag="RISK" value={riskLevel} accent={riskAccent} />
            <Chip
              tag="CONFIDENCE"
              value={confidence}
              accent={confAccent}
              tooltip={riskScore.confidence_explanation}
            />
            <Chip
              tag="LIQUIDITY"
              value={liquidity}
              accent={liqAccent}
              tooltip={riskScore.liquidity?.explanation}
            />
          </div>
        </Tooltip.Provider>

        <p className="mt-4 text-sm leading-relaxed text-slate-200">{summaryText}</p>
      </div>
    </section>
  )
}
