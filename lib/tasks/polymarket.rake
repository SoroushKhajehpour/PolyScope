# frozen_string_literal: true

namespace :polymarket do
  desc "Fetch raw Gamma API response (markets + search) and write to tmp. Phase 1.1 investigation."
  task dump_raw: :environment do
    client = PolymarketClient.new
    path_markets = Rails.root.join("tmp", "gamma_markets_raw.json")
    path_search = Rails.root.join("tmp", "gamma_search_raw.json")
    FileUtils.mkdir_p(Rails.root.join("tmp"))

    data_markets = client.markets(limit: 20, offset: 0, closed: false)
    File.write(path_markets, JSON.pretty_generate(data_markets))
    puts "Written #{data_markets.size} market(s) to #{path_markets}"

    data_search = client.search("supreme leader iran", limit_per_type: 5)
    File.write(path_search, JSON.pretty_generate(data_search))
    events_count = data_search["events"]&.size || 0
    puts "Written #{events_count} event(s) to #{path_search}"

    puts "\nInspect the JSON files to confirm event/market structure and key paths for title."
  end

  desc "Report events (event_id) and zero-volume markets for debugging."
  task report_events: :environment do
    total = Market.count
    with_vol = Market.with_volume.count
    zero_vol = total - with_vol
    with_event = Market.with_volume.where.not(event_id: [nil, ""]).count
    puts "Total markets: #{total}"
    puts "With volume (COALESCE(volume,0) > 0): #{with_vol}"
    puts "Zero/no volume: #{zero_vol}"
    puts "With non-null event_id (among with_volume): #{with_event}"

    puts "\n--- Events (event_id => count, sample title) ---"
    Market.with_volume.where.not(event_id: [nil, ""])
          .group(:event_id)
          .count
          .each do |eid, cnt|
      sample = Market.with_volume.find_by(event_id: eid)&.event_question
      puts "  #{eid} => #{cnt} markets | sample: #{sample&.truncate(60)}"
    end

    if zero_vol.positive?
      puts "\n--- Zero-volume markets (id, polymarket_id, question, event_id) ---"
      Market.where("COALESCE(volume, 0) <= 0").limit(50).each do |m|
        puts "  id=#{m.id} polymarket_id=#{m.polymarket_id} event_id=#{m.event_id.inspect} | #{m.question&.truncate(50)}"
      end
      puts "  ... (showing up to 50)" if zero_vol > 50
    end
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
