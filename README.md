# README

Polyscope is a Polymarket trading bot that aims to generate profit by identifying and acting on probability mismatches in markets. It:

Tracks market prices and metadata via the Gamma API

Monitors and decodes on-chain trades from the CTF Exchange contract on Polygon

Automates trade execution securely via the CLOB API with EIP-712 wallet authentication

Provides a foundation for data-driven trading strategies and analytics

* Dev Workflow

Terminal 1 - Rails: bin/dev
Terminal 2 - Sidekiq: bundle exec sidekiq
Terminal 3 - Redis: redis-server
