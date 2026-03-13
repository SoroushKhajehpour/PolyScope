import { router } from "@inertiajs/react"
import type { MarketSearchResult } from "@/types/market"
import { formatVolume, formatEndDate } from "@/lib/utils"

interface SearchResultsProps {
  results: MarketSearchResult[]
  visible: boolean
}

export default function SearchResults({ results, visible }: SearchResultsProps) {
  const handleClick = (result: MarketSearchResult) => {
    router.visit(`/markets/${result.event_id}`)
  }

  return (
    <div
      className={`overflow-hidden rounded-b-xl border border-t-0 border-white/8 bg-[#0F1420] transition-all duration-200 ${
        visible && results.length > 0
          ? "max-h-[480px] opacity-100"
          : "max-h-0 border-transparent opacity-0"
      }`}
    >
      <div className="max-h-[460px] overflow-y-auto">
        {results.map((result, index) => (
          <button
            key={result.event_id}
            onClick={() => handleClick(result)}
            className="group flex w-full items-center gap-3 border-b border-white/5 px-5 py-4 text-left transition-colors last:border-b-0 hover:bg-white/4"
            style={{
              animation: visible
                ? `fadeSlideIn 180ms ease-out ${index * 40}ms both`
                : "none",
            }}
          >
            {/* Thumbnail */}
            {result.event_image && (
              <img
                src={result.event_image}
                alt=""
                className="h-5 w-5 shrink-0 rounded-sm object-cover"
                crossOrigin="anonymous"
              />
            )}
            {!result.event_image && (
              <div className="flex h-5 w-5 shrink-0 items-center justify-center rounded-sm bg-white/5">
                <svg className="h-2.5 w-2.5 text-white/20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
            )}
            {/* Title */}
            <span className="flex-1 truncate text-base text-white transition-colors group-hover:text-[#F5A623]">
              {result.event_question}
            </span>
            {/* Category badge */}
            {result.category && (
              <span className="shrink-0 rounded bg-white/5 px-2 py-0.5 text-xs font-medium uppercase tracking-wide text-white/40">
                {result.category}
              </span>
            )}
            {/* Metadata */}
            <span className="shrink-0 text-sm text-white/30">
              {formatVolume(result.volume)}
            </span>
            <span className="shrink-0 text-sm text-white/30">
              {formatEndDate(result.end_date)}
            </span>
          </button>
        ))}
      </div>
    </div>
  )
}
