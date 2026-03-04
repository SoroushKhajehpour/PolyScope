class Market < ApplicationRecord
  include PgSearch::Model

  has_one :risk_score, dependent: :destroy
  has_many :disputes, dependent: :destroy
  has_many :clarifications, dependent: :destroy

  pg_search_scope :search, against: %i[question category], using: { tsearch: { prefix: true } }
end
