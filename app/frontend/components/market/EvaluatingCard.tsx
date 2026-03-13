import { useState, useEffect } from "react"
import type { MarketProps } from "@/types/market"
import { formatVolume, formatEndDate } from "@/lib/utils"

const statuses = [
  "> Fetching market data...",
  "> Running ambiguity analysis...",
  "> Scoring resolution factors...",
  "> Computing risk composite...",
  "> Finalizing report...",
]

interface EvaluatingCardProps {
  market: MarketProps
}

export default function EvaluatingCard({ market }: EvaluatingCardProps) {
  const [progress, setProgress] = useState(0)
  const [statusIndex, setStatusIndex] = useState(0)
  const [statusVisible, setStatusVisible] = useState(true)
  const [imageLoaded, setImageLoaded] = useState(false)
  const [imageError, setImageError] = useState(false)

  // Progress bar animation
  useEffect(() => {
    const start = performance.now()
    const duration = 7000
    const target = 82

    const tick = (now: number) => {
      const elapsed = now - start
      const t = Math.min(elapsed / duration, 1)
      const eased = 1 - Math.pow(1 - t, 3)
      setProgress(Math.round(eased * target))
      if (t < 1) requestAnimationFrame(tick)
    }

    requestAnimationFrame(tick)
  }, [])

  // Cycling status text
  useEffect(() => {
    const interval = setInterval(() => {
      setStatusVisible(false)
      setTimeout(() => {
        setStatusIndex((i) => (i + 1) % statuses.length)
        setStatusVisible(true)
      }, 250)
    }, 1800)
    return () => clearInterval(interval)
  }, [])

  return (
    <div
      style={{
        width: "90%",
        maxWidth: 520,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      }}
    >
      {/* Market image */}
      <div
        style={{
          width: 80,
          height: 80,
          borderRadius: 14,
          overflow: "hidden",
          marginBottom: 14,
          background: "#141824",
          flexShrink: 0,
        }}
      >
        {market.event_image && !imageError && (
          <img
            src={market.event_image}
            alt=""
            onLoad={() => setImageLoaded(true)}
            onError={() => setImageError(true)}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              opacity: imageLoaded ? 1 : 0,
              transition: "opacity 300ms ease",
            }}
          />
        )}
      </div>

      {/* Category tag */}
      <div
        style={{
          display: "inline-block",
          fontSize: 11,
          fontWeight: 600,
          letterSpacing: "0.12em",
          textTransform: "uppercase",
          color: "rgba(255,255,255,0.40)",
          background: "rgba(255,255,255,0.06)",
          border: "1px solid rgba(255,255,255,0.08)",
          borderRadius: 5,
          padding: "4px 12px",
          marginBottom: 12,
        }}
      >
        {market.category || "ANALYSIS"}
      </div>

      {/* Market title */}
      <div
        style={{
          fontSize: 22,
          fontWeight: 600,
          color: "rgba(255,255,255,0.90)",
          textAlign: "center",
          lineHeight: 1.35,
          letterSpacing: "-0.02em",
          display: "-webkit-box",
          WebkitLineClamp: 3,
          WebkitBoxOrient: "vertical",
          overflow: "hidden",
        }}
      >
        {market.event_question}
      </div>

      {/* Volume + end date row */}
      {(market.volume || market.end_date) && (
        <div
          style={{
            marginTop: 10,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 16,
          }}
        >
          {market.volume && (
            <div style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "rgba(255,255,255,0.35)" }}>
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <circle cx="6" cy="6" r="5" stroke="currentColor" strokeWidth="1" fill="none" />
                <text x="6" y="8" textAnchor="middle" fill="currentColor" fontSize="6" fontWeight="600">$</text>
              </svg>
              <span>{formatVolume(market.volume)}</span>
            </div>
          )}
          {market.end_date && (
            <div style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "rgba(255,255,255,0.35)" }}>
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                <rect x="1" y="2.5" width="10" height="8.5" rx="1.5" stroke="currentColor" strokeWidth="1" fill="none" />
                <line x1="1" y1="5" x2="11" y2="5" stroke="currentColor" strokeWidth="1" />
                <line x1="3.5" y1="1" x2="3.5" y2="3" stroke="currentColor" strokeWidth="1" strokeLinecap="round" />
                <line x1="8.5" y1="1" x2="8.5" y2="3" stroke="currentColor" strokeWidth="1" strokeLinecap="round" />
              </svg>
              <span>{formatEndDate(market.end_date)}</span>
            </div>
          )}
        </div>
      )}

      {/* Thin horizontal rule */}
      <hr
        style={{
          width: "100%",
          border: "none",
          borderTop: "1px solid rgba(255,255,255,0.06)",
          marginTop: 28,
          marginBottom: 28,
        }}
      />

      {/* ANALYSING row */}
      <div
        style={{
          width: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          marginBottom: 8,
        }}
      >
        <span
          style={{
            fontSize: 9,
            letterSpacing: "0.14em",
            textTransform: "uppercase",
            color: "rgba(255,255,255,0.22)",
          }}
        >
          ANALYSING
        </span>
        <div
          className="animate-dot-pulse"
          style={{
            width: 7,
            height: 7,
            borderRadius: "50%",
            background: "#5B6EF5",
          }}
        />
      </div>

      {/* Status text */}
      <div
        style={{
          width: "100%",
          marginBottom: 20,
          height: 18,
          display: "flex",
          alignItems: "center",
        }}
      >
        <span
          style={{
            fontSize: 13,
            fontFamily: "ui-monospace, 'JetBrains Mono', monospace",
            color: "rgba(255,255,255,0.50)",
            opacity: statusVisible ? 1 : 0,
            transition: "opacity 250ms ease",
          }}
        >
          {statuses[statusIndex]}
        </span>
        <span
          className="animate-blink"
          style={{
            fontSize: 13,
            color: "#5B6EF5",
            marginLeft: 2,
          }}
        >
          ▋
        </span>
      </div>

      {/* Progress bar */}
      <div
        style={{
          width: "100%",
          height: 2,
          background: "rgba(255,255,255,0.07)",
          borderRadius: 99,
          overflow: "hidden",
        }}
      >
        <div
          className="animate-bar-breathe"
          style={{
            height: "100%",
            borderRadius: 99,
            background: "#5B6EF5",
            width: `${progress}%`,
          }}
        />
      </div>

      {/* Percentage */}
      <div style={{ width: "100%", marginTop: 6, textAlign: "right" }}>
        <span
          style={{
            fontSize: 11,
            fontFamily: "ui-monospace, monospace",
            color: "rgba(255,255,255,0.22)",
          }}
        >
          {progress}%
        </span>
      </div>
    </div>
  )
}
