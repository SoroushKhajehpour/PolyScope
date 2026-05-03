# PolyScope

Resolution risk intelligence for Polymarket

## Why this exists

Polymarket traders routinely lose money not because they were wrong about the world, but because they misread the fine print.

Examples: 

**The Zelens'k'yy suit market ($242M in volume)** asked whether Zelenskyy would "wear a suit" before July 2025. He showed up to a NATO summit in formal attire. The market initially resolved Yes — then UMA voters reversed it to No nine days later, arguing the outfit didn't technically qualify as a "suit." Menswear experts couldn't even agree. Traders called it the biggest scam in Polymarket history.

**The Venezuela invasion market ($11M)** asked whether the U.S. would invade Venezuela. A Delta Force operation captured President Maduro with 150+ aircraft conducting airstrikes. Polymarket refused to pay out, arguing the operation didn't constitute an "invasion" because it lacked "territorial control."

**The Ukraine mineral deal ($7M)** resolved prematurely and incorrectly, burning traders who were on the right side of the outcome.

These aren't edge cases. They're a structural problem. Resolution criteria on prediction markets are often vague, subjective, or dependent on a small group of anonymous voters. By the time you realize the wording is ambiguous, your money is already locked in.

PolyScope scores every market before you trade so you can see where the risk actually is.

## What it does

Search any Polymarket question and get a risk score from 0–100 across five factors:

| Factor             | Weight | What it catches 

Resolution clarity   | 38%  | Vague wording, subjective criteria, room for misinterpretation |
Historical accuracy  | 18%  | How reliably similar markets have resolved in the past |
Time horizon         | 17%  | Settlement uncertainty from distant or undefined deadlines |
Manipulation risk    | 17%  | Thin volume, known-manipulable sources, structural exposure |
Information asymmetry| 10%  | Insider advantage, concentrated access to key data |

Liquidity is scored separately. Each factor includes a plain-English explanation of what drove the score.

## Stack

- Backend: Rails 8, PostgreSQL + pgvector, Sidekiq + Redis
- Frontend: React 19, TypeScript, Vite, Tailwind CSS, Inertia.js
- AI: Anthropic Claude (risk analysis), OpenAI embeddings (similar market matching)
- Data: Polymarket Gamma API, UMA dispute rates

## Setup

Requires Ruby, Node.js, PostgreSQL (with pgvector), and Redis.

```
cd app
bin/setup
```

Set environment variables:

```
ANTHROPIC_API_KEY=...
OPENAI_API_KEY=...
```

## Running

Start **Rails + Vite** together (pages and API):

```
bin/dev
```

Or the same thing via npm:

```
npm run dev:full
```

`npm run dev` alone only runs **Vite** (frontend assets). It does not start the Rails server, so opening `http://localhost:3000` will show nothing useful until you also run `bin/rails server` (or use `bin/dev` / `npm run dev:full` above).

**Sidekiq** is not started by `bin/dev`. Without it, scoring still works via the server’s inline fallback; for throughput and background jobs, start Redis, then in another terminal:

```
bundle exec sidekiq -C config/sidekiq.yml
```

Optional: strip `Co-authored-by:` lines from commits (e.g. IDE-added trailers):

```
git config core.hooksPath .githooks
```

### Troubleshooting (blank page or “not loading”)

1. **Use `bin/dev` (or `npm run dev:full`) from the `app/` directory**, not `npm run dev` alone.
2. **Open the Rails URL**: `http://localhost:3000` (Vite’s dev port, e.g. 3036, is only for HMR; the HTML comes from Rails).
3. **Pending migrations**: if you see a migration error in the browser or logs, run `bin/rails db:prepare` and reload.
4. **Browser devtools**: check the Console and Network tabs for failed JS (often Vite not reachable if Rails isn’t proxying to the Vite dev server).

To seed market data:

```
bundle exec rake polymarket:sync
```
