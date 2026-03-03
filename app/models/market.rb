class Market < ApplicationRecord
  include PgSearch::Model

  has_one :risk_score
  has_many :disputes
  has_many :clarifications

  pg_search_scope :search, against: %i[question category], using: { tsearch: { prefix: true } }
end
