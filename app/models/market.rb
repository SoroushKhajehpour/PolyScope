class Market < ApplicationRecord
  include PgSearch::Model

  MARKET_TYPES = %w[binary multi_outcome scalar].freeze

  validates :market_type, inclusion: { in: MARKET_TYPES }, allow_nil: true

  has_one :risk_score, dependent: :destroy
  has_many :disputes, dependent: :destroy
  has_many :clarifications, dependent: :destroy

  before_save :set_market_type, if: :market_type_blank?

  scope :with_volume, -> { where("COALESCE(volume, 0) > 0") }

  PER_PAGE_GROUPS = 36

  # Returns { display_units: [...], pagination: { total_pages, current_page, prev_page, next_page } }.
  # scope: relation with with_volume + risk + search already applied.
  # Each display unit is { type: :group, group_id:, markets: [...] } or { type: :standalone, market: }.
  def self.display_groups_page(scope, page: 1, per_page: PER_PAGE_GROUPS)
    page = [page.to_i, 1].max
    per_page = [per_page.to_i, 1].max

    group_count = scope.reorder(nil).select("COALESCE(markets.group_id, 'm'||markets.id::text)").distinct.count
    total_pages = [(group_count.to_f / per_page).ceil, 1].max
    current_page = [page, total_pages].min
    offset = (current_page - 1) * per_page

    # One row per display group (representative id + group_id), ordered by newest group first.
    sub = scope.reorder(nil).select(<<~SQL.squish)
      markets.id, markets.group_id, markets.created_at,
      COALESCE(markets.group_id, 'm'||markets.id::text) AS gk,
      MAX(markets.created_at) OVER (PARTITION BY COALESCE(markets.group_id, 'm'||markets.id::text)) AS group_max_created_at
    SQL
    sub_sql = sub.to_sql
    ranked = "SELECT * FROM (SELECT id, group_id, gk, group_max_created_at, ROW_NUMBER() OVER (PARTITION BY gk ORDER BY created_at DESC) AS rn FROM (#{sub_sql}) AS sub2) AS ranked WHERE rn = 1 ORDER BY group_max_created_at DESC LIMIT #{per_page.to_i} OFFSET #{offset.to_i}"
    rows = connection.select_all(ranked).to_a

    display_units = rows.map do |row|
      gid = row["group_id"].presence
      if gid.present?
        markets = scope.where(group_id: gid).order(created_at: :desc).to_a
        { type: :group, group_id: gid, markets: markets }
      else
        market = scope.find(row["id"])
        { type: :standalone, market: market }
      end
    end

    pagination = {
      total_pages: total_pages,
      current_page: current_page,
      prev_page: current_page > 1 ? current_page - 1 : nil,
      next_page: current_page < total_pages ? current_page + 1 : nil
    }
    { display_units: display_units, pagination: pagination }
  end

  pg_search_scope :search, against: %i[question category], using: { tsearch: { prefix: true } }

  # Returns "binary" | "multi_outcome" | "scalar" so the card can choose probability UI.
  def detect_market_type
    if multi_outcome?
      "multi_outcome"
    elsif scalar?
      "scalar"
    elsif binary?
      "binary"
    else
      "binary"
    end
  end

  private

  def market_type_blank?
    market_type.blank?
  end

  def set_market_type
    self.market_type = detect_market_type
  end

  def binary?
    yes_price.present? && no_price.present?
  end

  def multi_outcome?
    return false unless respond_to?(:outcomes)

    outcomes.is_a?(Array) && outcomes.size > 2
  end

  def scalar?
    return false unless respond_to?(:min_value) && respond_to?(:max_value)

    min_value.present? && max_value.present?
  end
end
