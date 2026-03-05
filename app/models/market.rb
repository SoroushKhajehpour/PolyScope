class Market < ApplicationRecord
  include PgSearch::Model

  has_one :risk_score, dependent: :destroy
  has_many :disputes, dependent: :destroy
  has_many :clarifications, dependent: :destroy

  scope :with_volume, -> { where("COALESCE(volume, 0) > 0") }

  PER_PAGE_EVENTS = 36

  # Returns { display_units: [...], pagination: { ... } }. One card per event (grouped by event_id).
  # Each unit is { type: :event, market: representative_market, total_volume: sum }.
  def self.display_events_page(scope, page: 1, per_page: PER_PAGE_EVENTS)
    page = [page.to_i, 1].max
    per_page = [per_page.to_i, 1].max

    # Distinct event keys: event_id when present, else fallback to single-market key
    sub = scope.reorder(nil).select(<<~SQL.squish)
      markets.id, markets.event_id, markets.event_question, markets.event_image,
      markets.created_at, markets.category,
      COALESCE(NULLIF(TRIM(markets.event_id), ''), 'm' || markets.id::text) AS ek,
      SUM(markets.volume) OVER (PARTITION BY COALESCE(NULLIF(TRIM(markets.event_id), ''), 'm' || markets.id::text)) AS event_volume,
      MAX(markets.created_at) OVER (PARTITION BY COALESCE(NULLIF(TRIM(markets.event_id), ''), 'm' || markets.id::text)) AS event_max_created_at
    SQL
    sub_sql = sub.to_sql
    event_count_sql = "SELECT COUNT(DISTINCT ek) FROM (#{sub_sql}) AS sub2"
    event_count = connection.select_value(event_count_sql).to_i
    total_pages = [(event_count.to_f / per_page).ceil, 1].max
    current_page = [page, total_pages].min
    offset = (current_page - 1) * per_page

    ranked_sql = <<~SQL.squish
      SELECT * FROM (
        SELECT id, event_id, event_question, event_image, category, ek, event_volume, event_max_created_at,
               ROW_NUMBER() OVER (PARTITION BY ek ORDER BY created_at DESC) AS rn
        FROM (#{sub_sql}) AS sub2
      ) AS ranked
      WHERE rn = 1
      ORDER BY event_max_created_at DESC
      LIMIT #{per_page.to_i} OFFSET #{offset.to_i}
    SQL
    rows = connection.select_all(ranked_sql).to_a

    display_units = rows.map do |row|
      event_id = row["event_id"].to_s.presence
      total_volume = row["event_volume"].to_f
      market = scope.find(row["id"])
      # Allow card to show event_question and total_volume
      { type: :event, market: market, total_volume: total_volume }
    end

    pagination = {
      total_pages: total_pages,
      current_page: current_page,
      prev_page: current_page > 1 ? current_page - 1 : nil,
      next_page: current_page < total_pages ? current_page + 1 : nil
    }
    { display_units: display_units, pagination: pagination }
  end

  # Build display_units from an array of markets for live search. One unit per event_id (first occurrence).
  def self.display_units_from_markets(markets_array)
    return [] if markets_array.blank?

    seen = []
    units = []
    markets_array.each do |m|
      ek = m.event_id.presence || "m#{m.id}"
      next if seen.include?(ek)
      seen << ek
      same_event = markets_array.select { |x| (x.event_id.presence || "m#{x.id}") == ek }
      rep = same_event.first
      total_volume = same_event.sum { |x| x.volume.to_f }
      units << { type: :event, market: rep, total_volume: total_volume }
    end
    units
  end

  pg_search_scope :search, against: %i[question event_question category], using: { tsearch: { prefix: true } }
end
