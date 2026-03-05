class Market < ApplicationRecord
  include PgSearch::Model

  has_one :risk_score, dependent: :destroy
  has_many :disputes, dependent: :destroy
  has_many :clarifications, dependent: :destroy

  scope :with_volume, -> { where("COALESCE(volume, 0) > 0") }

  pg_search_scope :search, against: %i[event_question category], using: { tsearch: { prefix: true } }
end
