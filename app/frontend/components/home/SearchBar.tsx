import { useEffect } from "react"

interface SearchBarProps {
  query: string
  onChange: (query: string) => void
  onFocus: () => void
  onBlur: () => void
  isFocused: boolean
  showResults: boolean
  inputRef?: React.RefObject<HTMLInputElement | null>
}

export default function SearchBar({
  query,
  onChange,
  onFocus,
  onBlur,
  isFocused,
  showResults,
  inputRef,
}: SearchBarProps) {
  const focusSearchInput = () => {
    inputRef?.current?.focus()
  }

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault()
        focusSearchInput()
      }
    }

    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [])

  return (
    <div
      className={`relative rounded-xl bg-[#0F1420] transition-all duration-200 ${
        showResults ? "rounded-b-none" : ""
      }`}
    >
      {/* Animated border glow - runs by default */}
      <div
        className={`absolute -inset-px overflow-hidden rounded-xl transition-opacity duration-300 ${
          isFocused ? "opacity-0" : "opacity-100"
        } ${showResults ? "rounded-b-none" : ""}`}
      >
        <div
          className="absolute inset-0 animate-border-glow"
          style={{
            background: `conic-gradient(from var(--border-angle, 0deg), transparent 70%, #2563EB 85%, #3B82F6 92%, #2563EB 100%, transparent 100%)`,
          }}
        />
        <div
          className={`absolute inset-px rounded-[11px] bg-[#0F1420] ${
            showResults ? "rounded-b-none" : ""
          }`}
        />
      </div>

      {/* Subtle blurred outer glow - moves randomly */}
      <div
        className={`pointer-events-none absolute -inset-[4px] rounded-2xl blur-sm transition-opacity duration-300 ${
          isFocused ? "opacity-0" : "opacity-20"
        } ${showResults ? "rounded-b-none" : ""}`}
      >
        <div
          className="absolute inset-0 animate-glow-wander-1"
          style={{ background: `radial-gradient(circle at 50% 50%, #3B82F6 0%, transparent 70%)` }}
        />
        <div
          className="absolute inset-0 animate-glow-wander-2"
          style={{ background: `radial-gradient(circle at 50% 50%, #2563EB 0%, transparent 60%)` }}
        />
        <div
          className="absolute inset-0 animate-glow-wander-3"
          style={{ background: `radial-gradient(circle at 50% 50%, #1D4ED8 0%, transparent 65%)` }}
        />
      </div>

      {/* Solid blue border for focused state */}
      <div
        className={`absolute -inset-px rounded-xl border border-[#2563EB] transition-opacity duration-300 ${
          isFocused ? "opacity-100" : "opacity-0"
        } ${showResults ? "rounded-b-none border-b-[#2563EB]/40" : ""}`}
      />

      {/* Subtle outer glow - only when focused */}
      <div
        className={`absolute -inset-px rounded-xl transition-opacity duration-300 ${
          isFocused ? "opacity-100" : "opacity-0"
        } ${showResults ? "rounded-b-none" : ""}`}
        style={{ boxShadow: "0 0 0 1px #3B82F6, 0 0 20px rgba(37, 99, 235, 0.2)" }}
      />

      <div className="relative flex min-h-[70px] items-center px-6 py-5 pr-6">
        <svg
          width="23"
          height="23"
          viewBox="0 0 20 20"
          fill="none"
          className="mr-4 shrink-0 text-white/30"
        >
          <path
            d="M17.5 17.5L13.875 13.875M15.8333 9.16667C15.8333 12.8486 12.8486 15.8333 9.16667 15.8333C5.48477 15.8333 2.5 12.8486 2.5 9.16667C2.5 5.48477 5.48477 2.5 9.16667 2.5C12.8486 2.5 15.8333 5.48477 15.8333 9.16667Z"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        <input
          ref={inputRef}
          type="text"
          value={query}
          onChange={(e) => onChange(e.target.value)}
          onFocus={onFocus}
          onBlur={onBlur}
          placeholder="Search any prediction market..."
          className="min-w-0 flex-1 pr-12 bg-transparent text-base text-white placeholder:text-white/45 focus:outline-none"
        />
        <div
          className={`ml-4 mr-4 flex items-center gap-1 transition-opacity duration-200 ${
            query ? "opacity-0" : "opacity-100"
          }`}
        >
          <button
            type="button"
            onMouseDown={(e) => e.preventDefault()}
            onClick={focusSearchInput}
            className="rounded border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-medium text-white/35 transition-colors hover:text-white/55"
            aria-label="Focus search (Command K)"
          >
            <kbd>⌘K</kbd>
          </button>
        </div>
      </div>
    </div>
  )
}
