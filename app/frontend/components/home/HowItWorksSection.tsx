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
        className={`absolute left-1/2 z-100 w-[340px] max-w-[calc(100vw-2rem)] -translate-x-1/2 transition-all duration-200 md:w-[360px] ${
          isHovered ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-[8px] opacity-0"
        }`}
        style={{ bottom: "calc(100% + 16px)", transitionTimingFunction: "cubic-bezier(0.16, 1, 0.3, 1)" }}
      >
        <div
          className="rounded-[14px] backdrop-blur-md"
          style={{
            background: "rgba(18, 18, 22, 0.97)",
            border: "1px solid rgba(255, 255, 255, 0.08)",
            borderTop: "1px solid rgba(124, 58, 237, 0.5)",
            padding: "22px 24px",
            boxShadow: "0 24px 60px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.04)",
          }}
        >
          {modal}
        </div>
        <div className="flex justify-center">
          <div
            style={{
              width: 0,
              height: 0,
              borderLeft: "6px solid transparent",
              borderRight: "6px solid transparent",
              borderTop: "6px solid rgba(255,255,255,0.08)",
            }}
          />
        </div>
      </div>

      <div
        className={`relative aspect-square cursor-pointer rounded-xl p-5 transition-all duration-150 ${
          isHovered
            ? "border border-white/15 bg-white/6"
            : "border border-white/6 bg-white/3"
        }`}
      >
        <span
          className={`absolute right-4 top-4 text-xs text-white/30 transition-opacity duration-150 ${
            isHovered ? "opacity-100" : "opacity-0"
          }`}
        >
          ↑
        </span>
        <div className="mb-2 font-mono text-xs text-white/30">{stepNumber}</div>
        <div className={`mb-2 text-[15px] font-semibold transition-colors duration-150 ${isHovered ? "text-white" : "text-white/80"}`}>
          {title}
        </div>
        <div className="text-[13px] leading-[1.6] text-white/45">{description}</div>
      </div>
    </div>
  )
}

export default function HowItWorksSection() {
  return (
    <div className="mx-auto mt-16 w-full max-w-6xl px-4 lg:px-6">
      <div
        className="mb-7 flex items-center justify-center gap-2 opacity-0"
        style={{ animation: "stepFadeIn 400ms ease-out 700ms forwards" }}
      >
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="text-white/70">
          <circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.2" />
          <path d="M7 6.5V10" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
          <circle cx="7" cy="4.5" r="0.75" fill="currentColor" />
        </svg>
        <span className="text-sm font-medium text-white/70">How It Works</span>
      </div>

      <div className="grid grid-cols-3 items-stretch gap-6">
        <HowItWorksCard
          stepNumber="01"
          title="Search any market"
          description="Type anything — a question, a topic, or paste a Polymarket URL"
          animationDelay={850}
          modal={
            <div>
              <div className="mb-[10px] text-base font-semibold tracking-[-0.01em] text-white/92">Finding your market</div>
              <p className="mb-4 text-sm leading-[1.65] text-white/55">
                Search for any prediction market by typing a question, a keyword, or a topic — for example &apos;Iran war&apos;, &apos;Bitcoin 100k&apos;, or &apos;Fed rate cut&apos;.
              </p>
              <p className="mb-4 text-sm leading-[1.65] text-white/55">
                We search Polymarket&apos;s full catalogue in real time and return the closest matching active markets. Click any result to begin the risk analysis.
              </p>
              <div className="flex items-center gap-2 border-t border-white/6 pt-3 text-xs text-white/30">
                <span>⚡</span>
                <span>Tip: You can paste a full Polymarket URL directly into the search bar</span>
              </div>
            </div>
          }
        />

        <HowItWorksCard
          stepNumber="02"
          title="We score 6 risk factors"
          description="Our engine analyses what could go wrong before the market resolves"
          animationDelay={1000}
          modal={
            <div>
              <div className="mb-[10px] text-base font-semibold tracking-[-0.01em] text-white/92">What we actually analyse</div>
              <p className="mb-3 text-sm leading-[1.65] text-white/55">
                Every market is scored across six independent risk dimensions:
              </p>
              <div className="space-y-0">
                {[
                  { code: "F1", name: "Ambiguity", desc: "Is the resolution question clearly written?" },
                  { code: "F2", name: "Source risk", desc: "Does it rely on a single or unreliable data source?" },
                  { code: "F3", name: "Timing risk", desc: "Could timing ambiguity affect when or if it resolves?" },
                  { code: "F4", name: "Subjectivity", desc: "Is the outcome open to interpretation?" },
                  { code: "F5", name: "Precedent", desc: "Has this type of market resolved cleanly before?" },
                  { code: "F6", name: "Similar outcomes", desc: "How have comparable markets historically resolved?" },
                ].map((factor, i) => (
                  <div key={factor.code} className={`flex items-baseline gap-3 py-2 ${i < 5 ? "border-b border-white/5" : ""}`}>
                    <span className="shrink-0 text-xs font-medium text-white/35">{factor.code}</span>
                    <span className="w-24 shrink-0 text-xs font-medium text-white/35">{factor.name}</span>
                    <span className="text-xs text-white/55">{factor.desc}</span>
                  </div>
                ))}
              </div>
            </div>
          }
        />

        <HowItWorksCard
          stepNumber="03"
          title="Understand your risk"
          description="Get a clear score, a plain-English verdict, and a full factor breakdown"
          animationDelay={1150}
          modal={
            <div>
              <div className="mb-[10px] text-base font-semibold tracking-[-0.01em] text-white/92">Reading your score</div>
              <p className="mb-4 text-sm leading-[1.65] text-white/55">
                Your result page shows a composite risk score from 0-100 and a risk level:
              </p>
              <div className="mb-4 space-y-2">
                {[
                  { level: "Low", range: "0-30", desc: "Market is clear, well-sourced, and likely to resolve cleanly", color: "#22C55E" },
                  { level: "Medium", range: "31-55", desc: "Some ambiguity present — worth reviewing before trading", color: "#F59E0B" },
                  { level: "High", range: "56-75", desc: "Meaningful risk of dispute or delayed resolution", color: "#F97316" },
                  { level: "Critical", range: "76-100", desc: "High chance of resolution failure, dispute, or restatement", color: "#EF4444" },
                ].map((tier) => (
                  <div key={tier.level} className="flex items-start gap-2">
                    <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full" style={{ backgroundColor: tier.color }} />
                    <div>
                      <span className="text-xs font-medium text-white/60">{tier.level} ({tier.range})</span>
                      <span className="ml-2 text-xs text-white/45">{tier.desc}</span>
                    </div>
                  </div>
                ))}
              </div>
              <div className="border-t border-white/6 pt-3 text-xs text-white/30">
                Scores are recomputed when market conditions change or new clarifications are issued by Polymarket.
              </div>
            </div>
          }
        />
      </div>
    </div>
  )
}
