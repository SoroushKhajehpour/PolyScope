interface RecentSearchesProps {
  searches: string[]
  visible: boolean
  onSelect: (query: string) => void
  onRemove: (index: number) => void
  onClearAll: () => void
}

export default function RecentSearches({
  searches,
  visible,
  onSelect,
  onRemove,
  onClearAll,
}: RecentSearchesProps) {
  return (
    <div
      className={`overflow-hidden rounded-b-xl border border-t-0 border-white/8 bg-[#0F1420] transition-all duration-150 ${
        visible && searches.length > 0
          ? "max-h-[400px] opacity-100"
          : "max-h-0 border-transparent opacity-0"
      }`}
      style={{
        animation: visible && searches.length > 0 ? "recentSearchesIn 150ms ease-out" : "none",
      }}
    >
      <div className="px-4 pb-1 pt-4">
        <span className="font-mono text-xs uppercase tracking-wider text-white/30">Recent</span>
      </div>
      <div>
        {searches.map((query, index) => (
          <div
            key={query}
            role="button"
            tabIndex={0}
            onClick={() => onSelect(query)}
            onKeyDown={(e) => e.key === "Enter" && onSelect(query)}
            className="group flex w-full cursor-pointer items-center gap-3 border-b border-white/5 px-4 py-3.5 text-left transition-colors last:border-b-0 hover:bg-white/4"
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="shrink-0 text-white/25">
              <circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.2" />
              <path d="M7 4V7L9 8.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
            </svg>
            <span className="flex-1 truncate text-sm text-white/70">{query}</span>
            <button
              onClick={(e) => {
                e.stopPropagation()
                onRemove(index)
              }}
              className="shrink-0 text-white/20 opacity-0 transition-opacity hover:text-white/40 group-hover:opacity-100"
            >
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <path d="M10.5 3.5L3.5 10.5M3.5 3.5L10.5 10.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
              </svg>
            </button>
          </div>
        ))}
      </div>
      <div className="py-4 text-center">
        <button
          onClick={onClearAll}
          className="text-sm text-white/25 transition-colors hover:text-white/40"
        >
          Clear recent searches
        </button>
      </div>
    </div>
  )
}
