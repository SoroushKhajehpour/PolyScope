# PolyScope
![PolyScope Logo](../polyscope-favicon.png)

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
- AI: Anthropic Claude (risk analysis — **required** for full scoring), OpenAI embeddings (similar-market factor — **optional**)
- Data: Polymarket Gamma API, UMA dispute rates

## Setup

Requires Ruby, Node.js, PostgreSQL (with pgvector), and Redis.

```
cd app
bin/setup
```

Set environment variables (Claude is enough to score markets; OpenAI only enhances similar-market matching):

```
ANTHROPIC_API_KEY=...
# Optional — enables embedding-based similar-market similarity:
# OPENAI_API_KEY=...
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


```
bundle exec sidekiq -C config/sidekiq.yml
```

Optional: strip `Co-authored-by:` lines from commits (e.g. IDE-added trailers):

```
git config core.hooksPath .githooks
```

### Troubleshooting (blank page or “not loading”)

1. **Use `bin/dev` (or `npm run dev:full`) from the `app/` directory**, not `npm run dev` alone.
2. **Open the app at `http://127.0.0.1:3000`** (or `localhost:3000`). HTML is served by Rails; in development, JS/CSS load **directly from Vite** at `127.0.0.1:3036` (`skipProxy`), so wait until the terminal shows Vite is ready before expecting the UI.
3. **Pending migrations**: if you see a migration error in the browser or logs, run `bin/rails db:prepare` and reload.
4. **Browser devtools**: open **Console** and **Network**. Failed requests to port **3036** mean Vite isn’t running yet or exited — fix the `vite` line in `bin/dev` output first.
5. **`A server is already running`**: remove the stale PID file `tmp/pids/server.pid` (or stop the old Puma), then start `bin/dev` again.

To seed market data:

```
bundle exec rake polymarket:sync
```
