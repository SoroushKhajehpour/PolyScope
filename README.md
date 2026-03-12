# README

## How Risk Scores Are Calculated

Each market gets six sub-scores (0 to 100), and then PolyScope computes a weighted average:

- Resolution Clarity (35%): how objective and verifiable the market outcome is.
- Time Horizon (15%): how far away the resolution date is.
- Liquidity (10%): execution risk from shallow order books.
- Historical Accuracy (15%): how reliably similar markets resolve.
- Manipulation Risk (15%): susceptibility to coordinated influence.
- Information Asymmetry (10%): whether key information is unevenly distributed.

The final score maps to:

- 0-25: Low risk
- 26-50: Moderate risk
- 51-75: High risk
- 76-100: Very high risk

PolyScope also shows a plain-English "Why this score?" explanation with a per-factor breakdown so users can see what drove the result and what kept it lower.
