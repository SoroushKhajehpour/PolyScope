# PolyScope

Resolution risk intelligence for Polymarket

## Why this exists

Polymarket traders routinely lose money not because they were wrong about the world, but because they misread the fine print.

Examples: 

**The Zelenskyy suit market ($242M in volume)** asked whether Zelenskyy would "wear a suit" before July 2025. He showed up to a NATO summit in formal attire. The market initially resolved Yes — then UMA voters reversed it to No nine days later, arguing the outfit didn't technically qualify as a "suit." Menswear experts couldn't even agree. Traders called it the biggest scam in Polymarket history.

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

```
bin/dev
```

This starts the Rails server, Vite dev server, and Sidekiq via Foreman.

To seed market data:

```
bundle exec rake polymarket:sync
```
