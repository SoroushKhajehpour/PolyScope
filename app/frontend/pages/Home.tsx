import { useState, useEffect, useRef } from "react"
import Layout from "@/components/layout/Layout"
import SearchBar from "@/components/home/SearchBar"
import SearchResults from "@/components/home/SearchResults"
import RecentSearches from "@/components/home/RecentSearches"
import HowItWorksSection from "@/components/home/HowItWorksSection"
import { useLiveSearch } from "@/hooks/useLiveSearch"
import { useRecentSearches } from "@/hooks/useRecentSearches"

export default function Home() {
  const [query, setQuery] = useState("")
  const [isFocused, setIsFocused] = useState(false)
  const [showResults, setShowResults] = useState(false)
  const [showRecentSearches, setShowRecentSearches] = useState(false)
  const [isEntering, setIsEntering] = useState(true)
  const inputRef = useRef<HTMLInputElement>(null)
  const blurTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const { results } = useLiveSearch(query)
  const recentSearches = useRecentSearches()

  // Entry animation
  useEffect(() => {
    const timer = setTimeout(() => setIsEntering(false), 600)
    return () => clearTimeout(timer)
  }, [])

  // Show results when there are results
  useEffect(() => {
    if (query.trim().length > 0 && results.length > 0) {
      setShowRecentSearches(false)
      const timer = setTimeout(() => setShowResults(true), 50)
      return () => clearTimeout(timer)
    } else if (query.trim().length > 0) {
      setShowRecentSearches(false)
      setShowResults(false)
    } else {
      setShowResults(false)
    }
  }, [query, results])

  const handleFocus = () => {
    setIsFocused(true)
    if (blurTimeoutRef.current) {
      clearTimeout(blurTimeoutRef.current)
      blurTimeoutRef.current = null
    }
    if (query.trim().length > 0 && results.length > 0) {
      setShowResults(true)
    } else if (query.length === 0 && recentSearches.searches.length > 0) {
      setShowRecentSearches(true)
    }
  }

  const handleBlur = () => {
    setIsFocused(false)
    blurTimeoutRef.current = setTimeout(() => {
      setShowRecentSearches(false)
      setShowResults(false)
    }, 150)
  }

  const handleRecentSearchClick = (q: string) => {
    setQuery(q)
    setShowRecentSearches(false)
    inputRef.current?.focus()
  }

  return (
    <Layout>
      <div className="mx-auto flex min-h-full w-full max-w-6xl flex-col px-6 pb-14 pt-8 lg:px-8">
        <div className="flex min-h-[60vh] w-full flex-col items-center justify-center gap-5 text-center">
          <div className="w-full max-w-3xl">
            {/* Logo and tagline */}
            <div
              className={`relative z-20 mb-6 transition-all duration-500 ${
                isEntering ? "translate-y-3 opacity-0" : "translate-y-0 opacity-100"
              }`}
            >
              <div
                className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
                style={{
                  width: "300px",
                  height: "200px",
                  background: "radial-gradient(ellipse at center, #2563EB 0%, transparent 70%)",
                  filter: "blur(80px)",
                  opacity: 0.15,
                }}
              />
              <div className="relative mb-5 flex items-center justify-center gap-3">
                <img src="/polyscope-logo.png" alt="PolyScope" className="h-24 w-24" />
                <h1 className="text-5xl font-semibold tracking-tight text-white">PolyScope</h1>
              </div>
              <p className="relative text-base tracking-wide text-white/50">
                Resolution risk intelligence for prediction markets
              </p>
            </div>
          </div>

          {/* Search container */}
          <div
            className={`relative w-full max-w-3xl transition-all delay-100 duration-500 ${
              isEntering ? "translate-y-3 opacity-0" : "translate-y-0 opacity-100"
            }`}
          >
            {/* Ambient glow behind search bar */}
            <div
              className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
              style={{
                width: "120%",
                height: "80px",
                background: "radial-gradient(ellipse 100% 100% at center, #1D4ED8 0%, transparent 70%)",
                filter: "blur(120px)",
                opacity: 0.08,
              }}
            />
            <SearchBar
              query={query}
              onChange={setQuery}
              onFocus={handleFocus}
              onBlur={handleBlur}
              isFocused={isFocused}
              showResults={showResults || showRecentSearches}
              inputRef={inputRef}
            />
            <RecentSearches
              searches={recentSearches.searches}
              visible={showRecentSearches && !showResults}
              onSelect={handleRecentSearchClick}
              onRemove={recentSearches.remove}
              onClearAll={recentSearches.clearAll}
            />
            <SearchResults results={results} visible={showResults} />
          </div>
        </div>
        <div className="w-full">
          <HowItWorksSection />
        </div>
      </div>
    </Layout>
  )
}
