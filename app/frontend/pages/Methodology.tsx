import Layout from "@/components/layout/Layout"
import { Link } from "@inertiajs/react"

export default function Methodology() {
  return (
    <Layout centerContent>
      <div className="mx-auto w-full max-w-3xl py-12">
        <Link
          href="/"
          className="mb-8 inline-flex items-center gap-1.5 text-[13px] font-medium text-slate-500 transition hover:text-slate-200"
        >
          ← Home
        </Link>

        <h1 className="mb-2 text-2xl font-semibold text-white">Methodology</h1>
        <p className="mb-10 text-sm text-slate-400">
          How PolyScope builds the composite score, what liquidity means, and what this product does
          not try to predict.
        </p>

        <section className="mb-10 space-y-3 text-sm leading-relaxed text-slate-200">
          <h2 className="text-base font-semibold text-white">Composite score</h2>
          <p>
            The headline number is a weighted blend of six rubric factors (each 0–100), mapped into
            levels (low / medium / high). Weights come from <code className="text-slate-400">config/risk_scoring.yml</code>{" "}
            and <code className="text-slate-400">RiskScoringConfig</code>:
          </p>
          <ul className="list-inside list-disc space-y-1 text-slate-300">
            <li>Resolution clarity / ambiguity (25%)</li>
            <li>Source dependency & information asymmetry (20%)</li>
            <li>Dispute / manipulation exposure (20%)</li>
            <li>Time / deadline specificity (15%)</li>
            <li>Liquidity stress within the rubric signal (10%)</li>
            <li>Historical accuracy from similar resolved markets (10%)</li>
          </ul>
          <p className="text-slate-400">
            Liquidity is also surfaced as its own plain-English note alongside the composite—it does
            not add extra points into the headline score on top of the rubric weight above.
          </p>
        </section>

        <section className="mb-10 space-y-3 text-sm leading-relaxed text-slate-200">
          <h2 className="text-base font-semibold text-white">Similar markets</h2>
          <p>
            “Similar” means embedding similarity within the same broad category, plus dispute and
            clarification signals from those markets. It is a pattern label for historical behavior,
            not a forecast of prices or outcomes.
          </p>
        </section>

        <section className="space-y-3 text-sm leading-relaxed text-slate-200">
          <h2 className="text-base font-semibold text-white">Limitations</h2>
          <p>
            Scores depend on available text, API data, and model passes at query time. Rules can
            change after a score is computed—use the freshness banner and criteria timeline on the
            market page. PolyScope does not execute trades and does not guarantee resolution outcomes.
          </p>
        </section>
      </div>
    </Layout>
  )
}
