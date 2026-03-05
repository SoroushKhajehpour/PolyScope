# frozen_string_literal: true

namespace :polymarket do
  desc "Run Polymarket sync once (fetch markets from API into DB). Use for testing step 25."
  task sync: :environment do
    puts "Running PolymarketSyncJob..."
    PolymarketSyncJob.perform_now
    puts "Done. Markets in DB: #{Market.count}"
  end

  desc "Remove all closed markets and their dependent records (risk_scores, disputes, clarifications). Run after ensuring sync/hydration only pull active markets."
  task remove_closed_markets: :environment do
    count = Market.where(status: "closed").count
    puts "Found #{count} closed markets. Destroying (cascades to risk_scores, disputes, clarifications, votes)..."
    Market.where(status: "closed").find_each(&:destroy)
    puts "Done. Remaining markets: #{Market.count}"
  end
end
