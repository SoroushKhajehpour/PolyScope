# frozen_string_literal: true

namespace :polymarket do
  desc "Run Polymarket sync once (fetch markets from API into DB). Use for testing step 25."
  task sync: :environment do
    puts "Running PolymarketSyncJob..."
    PolymarketSyncJob.perform_now
    puts "Done. Markets in DB: #{Market.count}"
  end
end
