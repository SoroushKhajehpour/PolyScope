# frozen_string_literal: true

# Seed file for development — populates all tables with fake data.
# Run with: bin/rails db:seed
# Or reset and seed: bin/rails db:reset

return unless Rails.env.development?

puts "Seeding development data..."

# ——— Markets ———
markets_data = [
  {
    polymarket_id: "pm_rain_001",
    question: "Will it rain in NYC tomorrow?",
    resolution_criteria: "Based on NOAA Central Park weather station. Rain = 0.01+ inches precipitation.",
    category: "Weather",
    end_date: 1.week.from_now,
    status: "active",
    yes_price: 0.65,
    no_price: 0.35,
    volume: 12_500
  },
  {
    polymarket_id: "pm_election_002",
    question: "Will Candidate X win the election?",
    resolution_criteria: "Resolves based on official certified election results.",
    category: "Politics",
    end_date: 1.month.from_now,
    status: "active",
    yes_price: 0.80,
    no_price: 0.20,
    volume: 85_000
  },
  {
    polymarket_id: "pm_sports_003",
    question: "Will Team A win the championship?",
    resolution_criteria: "Resolves to Yes if Team A wins the finals. Overtime counts.",
    category: "Sports",
    end_date: 2.weeks.from_now,
    status: "active",
    yes_price: 0.45,
    no_price: 0.55,
    volume: 32_000
  },
  {
    polymarket_id: "pm_geo_004",
    question: "Will the Iranian regime fall by June 30?",
    resolution_criteria: "Resolves Yes if the current government is no longer in power per major news consensus.",
    category: "Geopolitics",
    end_date: 4.months.from_now,
    status: "active",
    yes_price: 0.22,
    no_price: 0.78,
    volume: 2_100_000
  },
  {
    polymarket_id: "pm_crypto_005",
    question: "Will BTC exceed $100k by end of 2025?",
    resolution_criteria: "Resolves using CoinGecko spot price. Any exchange reporting $100,000 or higher counts.",
    category: "Crypto",
    end_date: 10.months.from_now,
    status: "active",
    yes_price: 0.58,
    no_price: 0.42,
    volume: 4_200_000
  },
  {
    polymarket_id: "pm_politics_006",
    question: "Will Sweden join NATO before July 2025?",
    resolution_criteria: "Resolves Yes upon official NATO announcement of Sweden's accession.",
    category: "Politics",
    end_date: 5.months.from_now,
    status: "active",
    yes_price: 0.91,
    no_price: 0.09,
    volume: 890_000
  },
  {
    polymarket_id: "pm_sports_007",
    question: "Will the Lakers make the NBA playoffs in 2025?",
    resolution_criteria: "Resolves based on official NBA standings at end of regular season.",
    category: "Sports",
    end_date: 3.months.from_now,
    status: "active",
    yes_price: 0.62,
    no_price: 0.38,
    volume: 156_000
  },
  {
    polymarket_id: "pm_finance_008",
    question: "Will the Fed cut rates in Q2 2025?",
    resolution_criteria: "Resolves Yes if the Federal Reserve lowers the federal funds rate at any meeting in Apr–Jun 2025.",
    category: "Finance",
    end_date: 4.months.from_now,
    status: "active",
    yes_price: 0.48,
    no_price: 0.52,
    volume: 1_800_000
  },
  {
    polymarket_id: "pm_geo_009",
    question: "Will Taiwan see a major military incident by Dec 2025?",
    resolution_criteria: "Resolves Yes if a significant armed conflict or invasion occurs per Reuters/AP.",
    category: "Geopolitics",
    end_date: 10.months.from_now,
    status: "active",
    yes_price: 0.18,
    no_price: 0.82,
    volume: 520_000
  },
  {
    polymarket_id: "pm_crypto_010",
    question: "Will ETH trade above $5,000 in 2025?",
    resolution_criteria: "Resolves using CoinGecko ETH/USD. Any single day above $5,000 counts.",
    category: "Crypto",
    end_date: 10.months.from_now,
    status: "active",
    yes_price: 0.35,
    no_price: 0.65,
    volume: 980_000
  },
  {
    polymarket_id: "pm_politics_011",
    question: "Will the UK hold a general election in 2025?",
    resolution_criteria: "Resolves based on official announcement of a UK general election date within the calendar year.",
    category: "Politics",
    end_date: 11.months.from_now,
    status: "active",
    yes_price: 0.72,
    no_price: 0.28,
    volume: 640_000
  },
  {
    polymarket_id: "pm_sports_012",
    question: "Will Brazil win the 2026 FIFA World Cup?",
    resolution_criteria: "Resolves to Yes if Brazil wins the final match of the 2026 World Cup.",
    category: "Sports",
    end_date: 2.years.from_now,
    status: "active",
    yes_price: 0.14,
    no_price: 0.86,
    volume: 2_400_000
  }
]

markets = markets_data.map do |attrs|
  Market.find_or_create_by!(polymarket_id: attrs[:polymarket_id]) do |m|
    m.assign_attributes(attrs)
  end
end

puts "  Created #{markets.size} markets"

# ——— Risk Scores (one per market) ———
markets.each do |market|
  score = rand(15..85)
  level = case score
          when 0..25 then "low"
          when 26..50 then "medium"
          when 51..75 then "high"
          else "critical"
          end

  RiskScore.find_or_create_by!(market: market) do |rs|
    rs.score = score
    rs.level = level
    rs.factors = {
      "ambiguity" => rand(0..25),
      "source_dependency" => rand(0..20),
      "historical_dispute_rate" => rand(0..20),
      "time_specification" => rand(0..15),
      "clarification_count" => rand(0..10),
      "similar_outcomes" => rand(0..10)
    }
  end
end

# Ensure at least one market per risk level so the grid shows all badge types
[
  [markets[0], "low", 18],
  [markets[1], "medium", 38],
  [markets[2], "high", 68],
  [markets[3], "critical", 88]
].each do |market, level, score|
  RiskScore.find_by!(market: market).update!(level: level, score: score)
end

puts "  Created risk scores for #{markets.size} markets"

# ——— Wallets ———
wallet_addresses = [
  "0x1111111111111111111111111111111111111111",
  "0x2222222222222222222222222222222222222222",
  "0x3333333333333333333333333333333333333333",
  "0x4444444444444444444444444444444444444444",
  "0x5555555555555555555555555555555555555555"
]

wallets = wallet_addresses.map do |addr|
  Wallet.find_or_create_by!(address: addr) do |w|
    w.total_votes = rand(10..150)
    w.accuracy_rate = rand(60..95) / 100.0
  end
end

puts "  Created #{wallets.size} wallets"

# ——— Disputes (some markets have disputes) ———
disputes = []
markets.first(2).each_with_index do |market, i|
  dispute = Dispute.find_or_create_by!(market: market, question_id: "q#{market.polymarket_id}") do |d|
    d.proposed_outcome = %w[Yes No].sample
    d.final_outcome = d.proposed_outcome
    d.total_votes_for = rand(50..200)
    d.total_votes_against = rand(10..80)
    d.voter_count = rand(5..25)
  end
  disputes << dispute
end

puts "  Created #{disputes.size} disputes"

# ——— Votes (wallets vote on disputes) ———
vote_count = 0
disputes.each do |dispute|
  wallets.sample(rand(2..4)).each do |wallet|
    Vote.find_or_create_by!(dispute: dispute, wallet: wallet) do |v|
      v.vote_direction = %w[for against].sample
      v.token_amount = rand(10..500) + rand.round(2)
    end
    vote_count += 1
  end
end

puts "  Created #{vote_count} votes"

# ——— Clarifications (resolution criteria changes) ———
clarifications_data = [
  {
    previous_text: "Resolution based on official source.",
    new_text: "Resolution based on official source as of market end date."
  },
  {
    previous_text: "Resolves based on certified results.",
    new_text: "Resolves based on certified results. Mail-in ballots included."
  }
]

clarifications_count = 0
markets.first(2).each_with_index do |market, i|
  data = clarifications_data[i]
  Clarification.find_or_create_by!(market: market, previous_text: data[:previous_text], new_text: data[:new_text]) do |c|
    c.diff_html = "<span class=\"del\">#{data[:previous_text]}</span> <span class=\"ins\">#{data[:new_text]}</span>"
    c.detected_at = rand(1..7).days.ago
  end
  clarifications_count += 1
end

puts "  Created #{clarifications_count} clarifications"

puts "Done! Seeded #{markets.size} markets, #{wallets.size} wallets, #{disputes.size} disputes, #{vote_count} votes, #{clarifications_count} clarifications."
puts "Run bin/rails db:reset to wipe and re-seed."
