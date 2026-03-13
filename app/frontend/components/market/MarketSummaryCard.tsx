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
  const formatted = value.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())
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

export default function MarketSummaryCard({ riskScore }: MarketSummaryCardProps) {
  const riskLevel = formatValue(riskScore.level, "Unknown")
  const confidence = formatValue(riskScore.confidence_tier, "Unknown")
  const rawLiquidity = formatValue(riskScore.liquidity?.label ?? null, "Unknown")
  const liquidity = stripRedundantWord("liquidity", rawLiquidity)
  const summaryText = riskScore.summary || riskScore.confidence_note || "No summary available."

  const riskAccent = chipAccent(riskScore.level)
  const confAccent = confidenceAccent(riskScore.confidence_tier ?? "unknown")
  const liqAccent = liquidityAccent(riskScore.liquidity?.label ?? "unknown")

  const chips: Array<{ tag: string; value: string; accent: ChipAccent }> = [
    { tag: "RISK", value: riskLevel, accent: riskAccent },
    { tag: "CONFIDENCE", value: confidence, accent: confAccent },
    { tag: "LIQUIDITY", value: liquidity, accent: liqAccent },
  ]

  return (
    <section className="rounded-md border border-white/8 bg-white/3">
      <div className="border-b border-white/6 px-5 py-3">
        <h2 className="text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
          Market Summary
        </h2>
      </div>

      <div className="p-5">
        {/* Chips row */}
        <div className="flex flex-wrap items-stretch gap-2">
          {chips.map((chip) => {
            const styles = ACCENT_STYLES[chip.accent]
            return (
              <div
                key={chip.tag}
                className={`flex items-baseline gap-2 border-l-[3px] ${styles.border} bg-white/4 py-1.5 pr-3.5 pl-3`}
              >
                <span className="font-mono text-[10px] font-medium tracking-wider text-slate-500">
                  {chip.tag}
                </span>
                <span className={`text-[13px] font-semibold ${styles.text}`}>
                  {chip.value}
                </span>
              </div>
            )
          })}
        </div>

        {/* Summary prose */}
        <p className="mt-4 text-sm leading-relaxed text-slate-200">{summaryText}</p>
      </div>
    </section>
  )
}
