import { ReactNode } from "react"
import { Link } from "@inertiajs/react"
import StockTickerBar from "./StockTickerBar"

function HomeIcon() {
  return (
    <svg
      className="block h-5 w-5 shrink-0 text-slate-200 transition-colors group-hover:text-white"
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.2"
      strokeLinecap="round"
      strokeLinejoin="round"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      focusable="false"
    >
      <path d="M3 10.5 12 3l9 7.5" />
      <path d="M5 10v10h5v-6h4v6h5V10" />
    </svg>
  )
}

function WatchlistIcon() {
  return (
    <svg
      className="block h-5 w-5 shrink-0 text-slate-200 transition-colors group-hover:text-white"
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.2"
      strokeLinecap="round"
      strokeLinejoin="round"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      focusable="false"
    >
      <path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  )
}

interface LayoutProps {
  children: ReactNode
  centerContent?: boolean
}

export default function Layout({ children, centerContent = false }: LayoutProps) {
  return (
    <div className="relative flex min-h-screen w-full max-w-full flex-col overflow-hidden bg-[#0A0E1A]">
      {/* Behind all content — was previously after <header> and painted over the nav */}
      <div
        className="pointer-events-none absolute inset-0 z-0 opacity-[0.03]"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='1'%3E%3Ccircle cx='1' cy='1' r='0.8'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
        }}
      />

      <header className="relative z-50 h-[90px] w-full shrink-0">
        {/* Decorative ticker — must not capture clicks or cover nav */}
        <div className="pointer-events-none absolute inset-0 z-0 min-h-[90px]">
          <StockTickerBar />
        </div>
        <nav
          className="relative z-20 isolate flex justify-end gap-6 px-4 pt-3 text-[12px] font-medium"
          aria-label="Primary"
        >
          <Link
            href="/"
            className="group inline-flex items-center gap-2 text-slate-200 transition hover:text-white"
            aria-label="Home"
          >
            <HomeIcon />
            <span>Home</span>
          </Link>
          <Link
            href="/watchlist"
            className="group inline-flex items-center gap-2 text-slate-200 transition hover:text-white"
            aria-label="Watchlist"
          >
            <WatchlistIcon />
            <span>Watchlist</span>
          </Link>
        </nav>
      </header>

      <main className="relative z-10 w-full flex-1">
        <div className={centerContent ? "mx-auto w-full max-w-5xl px-4 sm:px-6 lg:px-8" : "w-full"}>
          {children}
        </div>
      </main>
    </div>
  )
}
