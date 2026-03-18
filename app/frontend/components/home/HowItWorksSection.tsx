import { useState, ReactNode } from "react"

function HowItWorksCard({
  stepNumber,
  title,
  description,
  animationDelay,
  modal,
}: {
  stepNumber: string
  title: string
  description: string
  animationDelay: number
  modal: ReactNode
}) {
  const [isHovered, setIsHovered] = useState(false)

  return (
    <div
      className="relative h-full opacity-0"
      style={{ animation: `stepFadeIn 400ms ease-out ${animationDelay}ms forwards` }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Hover modal */}
      <div
        className={`absolute left-1/2 z-[50] w-[340px] max-w-[calc(100vw-2rem)] -translate-x-1/2 transition-all duration-200 md:w-[380px] ${
          isHovered ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-[8px] opacity-0"
        }`}
        style={{ bottom: "calc(100% + 14px)", transitionTimingFunction: "cubic-bezier(0.16, 1, 0.3, 1)" }}
      >
        <div
          className="rounded-2xl"
          style={{
            background: "#FFFFFF",
            border: "1px solid #E5E7EB",
            borderTop: "2px solid #7C3AED",
            padding: "24px 26px",
            boxShadow: "0 20px 50px rgba(0,0,0,0.08), 0 8px 20px rgba(0,0,0,0.04), 0 0 0 1px rgba(0,0,0,0.03)",
          }}
        >
          {modal}
        </div>
        <div className="flex justify-center">
          <div
            style={{
              width: 0,
              height: 0,
              borderLeft: "7px solid transparent",
              borderRight: "7px solid transparent",
              borderTop: "7px solid #E5E7EB",
            }}
          />
        </div>
      </div>

      {/* Card */}
      <div
        className="relative flex h-full cursor-pointer flex-col rounded-2xl p-6 transition-all duration-200"
        style={{
          background: isHovered ? "#FFFFFF" : "#FAFAFA",
          border: isHovered ? "1px solid #D1D5DB" : "1px solid #E5E7EB",
          boxShadow: isHovered
            ? "0 8px 30px rgba(0,0,0,0.08), 0 2px 8px rgba(0,0,0,0.04)"
            : "0 1px 3px rgba(0,0,0,0.04)",
        }}
      >
        {/* Hover hint */}
        <span
          className={`absolute right-5 top-5 text-xs transition-all duration-200 ${
            isHovered ? "translate-y-0 opacity-100" : "translate-y-1 opacity-0"
          }`}
          style={{ color: "#7C3AED" }}
        >
          ↑
        </span>

        {/* Step number */}
        <div
          className="mb-4 flex h-10 w-10 items-center justify-center rounded-lg font-mono text-sm font-semibold"
          style={{
            background: isHovered ? "#7C3AED" : "#F3F0FF",
            color: isHovered ? "#FFFFFF" : "#7C3AED",
            transition: "all 200ms ease",
          }}
        >
          {stepNumber}
        </div>

        {/* Title */}
        <div
          className="mb-2 text-base font-semibold tracking-[-0.01em] transition-colors duration-200"
          style={{ color: "#111827" }}
        >
          {title}
        </div>

        {/* Description */}
        <div
          className="text-[13.5px] leading-[1.65]"
          style={{ color: "#6B7280" }}
        >
          {description}
        </div>

        {/* Connector line (visual flow between cards) */}
        {stepNumber !== "03" && (
          <div
            className="absolute right-0 top-1/2 hidden -translate-y-1/2 translate-x-1/2 lg:block"
            style={{ zIndex: 10 }}
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M8 12H16M16 12L13 9M16 12L13 15" stroke="#D1D5DB" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
        )}
      </div>
    </div>
  )
}

export default function HowItWorksSection() {
  return (
    <div className="mx-auto mt-16 w-full max-w-6xl px-4 lg:px-6">
      {/* Section header */}
      <div
        className="mb-8 flex flex-col items-center gap-2 opacity-0"
        style={{ animation: "stepFadeIn 400ms ease-out 700ms forwards" }}
      >
        <div className="flex items-center gap-2">
          <div
            className="flex h-4 w-4 items-center justify-center rounded-full"
            style={{ background: "#F3F0FF" }}
          >
            <svg width="9" height="9" viewBox="0 0 14 14" fill="none">
              <circle cx="7" cy="7" r="6" stroke="#7C3AED" strokeWidth="1.5" />
              <path d="M7 6.5V10" stroke="#7C3AED" strokeWidth="1.5" strokeLinecap="round" />
              <circle cx="7" cy="4.5" r="0.75" fill="#7C3AED" />
            </svg>
          </div>
          <span className="text-sm font-semibold tracking-wide uppercase" style={{ color: "#7C3AED", letterSpacing: "0.05em" }}>
            How It Works
          </span>
        </div>
        <p className="text-sm" style={{ color: "#9CA3AF" }}>
          Three steps to smarter prediction market decisions
        </p>
      </div>

      <div className="grid grid-cols-3 items-stretch gap-5 lg:gap-7">
        <HowItWorksCard
          stepNumber="01"
          title="Search any market"
          description="Type anything — a question, a topic, or paste a Polymarket URL"
          animationDelay={850}
          modal={
            <div>
              <div className="mb-3 text-[15px] font-semibold tracking-[-0.01em]" style={{ color: "#111827" }}>
                Finding your market
              </div>
              <p className="mb-4 text-sm leading-[1.7]" style={{ color: "#6B7280" }}>
                Search for any prediction market by typing a question, a keyword, or a topic — for example &apos;Iran war&apos;, &apos;Bitcoin 100k&apos;, or &apos;Fed rate cut&apos;.
              </p>
              <p className="mb-4 text-sm leading-[1.7]" style={{ color: "#6B7280" }}>
                We search Polymarket&apos;s full catalogue in real time and return the closest matching active markets. Click any result to begin the risk analysis.
              </p>
              <div
                className="flex items-center gap-2 pt-3 text-xs"
                style={{ borderTop: "1px solid #F3F4F6", color: "#9CA3AF" }}
              >
                <span style={{ color: "#7C3AED" }}>⚡</span>
                <span>Tip: You can paste a full Polymarket URL directly into the search bar</span>
              </div>
            </div>
          }
        />

        <HowItWorksCard
          stepNumber="02"
          title="We score 5 risk factors"
          description="Our engine analyses what could go wrong before the market resolves"
          animationDelay={1000}
          modal={
            <div>
              <div className="mb-3 text-[15px] font-semibold tracking-[-0.01em]" style={{ color: "#111827" }}>
                What we actually analyse
              </div>
              <p className="mb-3 text-sm leading-[1.7]" style={{ color: "#6B7280" }}>
                Every market is scored across five core risk factors:
              </p>
              <div className="space-y-0">
                {[
                  { code: "F1", name: "Resolution clarity", desc: "How precise and verifiable the resolution criteria are." },
                  { code: "F2", name: "Time horizon", desc: "How much timing uncertainty exists before settlement." },
                  { code: "F3", name: "Historical accuracy", desc: "How reliably similar markets have resolved in the past." },
                  { code: "F4", name: "Manipulation risk", desc: "How exposed the market is to manipulation or adverse structure." },
                  { code: "F5", name: "Information asymmetry", desc: "How unevenly market-moving information is distributed." },
                ].map((factor, i) => (
                  <div
                    key={factor.code}
                    className="flex items-baseline gap-3 py-[9px]"
                    style={{ borderBottom: i < 4 ? "1px solid #F3F4F6" : "none" }}
                  >
                    <span
                      className="shrink-0 rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold"
                      style={{ background: "#F3F0FF", color: "#7C3AED" }}
                    >
                      {factor.code}
                    </span>
                    <span className="w-[120px] shrink-0 text-xs font-medium" style={{ color: "#374151" }}>
                      {factor.name}
                    </span>
                    <span className="text-xs" style={{ color: "#9CA3AF" }}>{factor.desc}</span>
                  </div>
                ))}
              </div>
            </div>
          }
        />

        <HowItWorksCard
          stepNumber="03"
          title="Understand your risk"
          description="Get a clear score, plain-English verdict, and tabbed analysis"
          animationDelay={1150}
          modal={
            <div>
              <div className="mb-3 text-[15px] font-semibold tracking-[-0.01em]" style={{ color: "#111827" }}>
                Reading your score
              </div>
              <p className="mb-4 text-sm leading-[1.7]" style={{ color: "#6B7280" }}>
                Your result page shows a composite risk score from 0-100 and a risk level:
              </p>
              <div className="mb-4 space-y-2.5">
                {[
                  { level: "Low", range: "0-39", desc: "Market is clear, well-sourced, and likely to resolve cleanly", color: "#22C55E", bg: "#F0FDF4" },
                  { level: "Medium", range: "40-69", desc: "Some ambiguity present — worth reviewing before trading", color: "#F59E0B", bg: "#FFFBEB" },
                  { level: "High", range: "70-100", desc: "High chance of dispute, delayed resolution, or market manipulation", color: "#EF4444", bg: "#FEF2F2" },
                ].map((tier) => (
                  <div key={tier.level} className="flex items-start gap-2.5">
                    <span
                      className="mt-[5px] flex h-5 w-5 shrink-0 items-center justify-center rounded-full"
                      style={{ backgroundColor: tier.bg }}
                    >
                      <span className="h-2 w-2 rounded-full" style={{ backgroundColor: tier.color }} />
                    </span>
                    <div>
                      <span className="text-xs font-semibold" style={{ color: "#374151" }}>
                        {tier.level} ({tier.range})
                      </span>
                      <span className="ml-1.5 text-xs" style={{ color: "#9CA3AF" }}>{tier.desc}</span>
                    </div>
                  </div>
                ))}
              </div>
              <div
                className="pt-3 text-xs"
                style={{ borderTop: "1px solid #F3F4F6", color: "#9CA3AF" }}
              >
                Scores are recomputed when market conditions change or new clarifications are issued by Polymarket.
              </div>
            </div>
          }
        />
      </div>
    </div>
  )
}
