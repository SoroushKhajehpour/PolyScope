import { ReactNode } from "react"
import StockTickerBar from "./StockTickerBar"

interface LayoutProps {
  children: ReactNode
  centerContent?: boolean
}

export default function Layout({ children, centerContent = false }: LayoutProps) {
  return (
    <div className="relative flex min-h-screen w-full flex-col overflow-hidden bg-[#0A0E1A]">
      <header className="relative z-20 h-[90px] w-full shrink-0">
        <StockTickerBar />
      </header>
      {/* Background grid pattern */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.04]"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='1'%3E%3Ccircle cx='1' cy='1' r='1'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
        }}
      />
      <main className={`relative z-10 flex-1 ${centerContent ? "flex w-full justify-center" : ""}`}>
        <div className={centerContent ? "mx-auto w-full max-w-5xl" : "w-full"}>
          {children}
        </div>
      </main>
    </div>
  )
}
