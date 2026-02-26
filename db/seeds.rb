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
