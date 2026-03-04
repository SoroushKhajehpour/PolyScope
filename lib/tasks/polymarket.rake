# frozen_string_literal: true

namespace :polymarket do
  # TEMPORARY: Phase 1.1 audit — dump raw Gamma API response for documentation. Remove in Phase 5.
  desc "Dump raw Gamma API markets response to tmp/gamma_sample.json (limit: 5). No transform."
  task dump_api_sample: :environment do
    data = PolymarketClient.new.markets(limit: 5, offset: 0, closed: false)
    path = Rails.root.join("tmp", "gamma_sample.json")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(data))
    puts "Dumped #{data.size} market(s) to #{path}"
  end

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
