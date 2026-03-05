# frozen_string_literal: true

namespace :polymarket do
  desc "Report display groups and zero-volume markets for debugging."
  task report_groups: :environment do
    total = Market.count
    with_vol = Market.with_volume.count
    zero_vol = total - with_vol
    with_group = Market.with_volume.where.not(group_id: [nil, ""]).count
    puts "Total markets: #{total}"
    puts "With volume (COALESCE(volume,0) > 0): #{with_vol}"
    puts "Zero/no volume: #{zero_vol}"
    puts "With non-null group_id (among with_volume): #{with_group}"

    puts "\n--- Groups (group_id => count, sample question) ---"
    Market.with_volume.where.not(group_id: [nil, ""])
          .group(:group_id)
          .count
          .each do |gid, cnt|
      sample = Market.with_volume.find_by(group_id: gid)&.question
      puts "  #{gid} => #{cnt} markets | sample: #{sample&.truncate(60)}"
    end

    if zero_vol.positive?
      puts "\n--- Zero-volume markets (id, polymarket_id, question, group_id) ---"
      Market.where("COALESCE(volume, 0) <= 0").limit(50).each do |m|
        puts "  id=#{m.id} polymarket_id=#{m.polymarket_id} group_id=#{m.group_id.inspect} | #{m.question&.truncate(50)}"
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
