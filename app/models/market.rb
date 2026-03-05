class Market < ApplicationRecord
  include PgSearch::Model

  MARKET_TYPES = %w[binary multi_outcome scalar].freeze

  validates :market_type, inclusion: { in: MARKET_TYPES }, allow_nil: true

  has_one :risk_score, dependent: :destroy
  has_many :disputes, dependent: :destroy
  has_many :clarifications, dependent: :destroy

  before_save :set_market_type, if: :market_type_blank?

  scope :with_volume, -> { where("COALESCE(volume, 0) > 0") }

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
