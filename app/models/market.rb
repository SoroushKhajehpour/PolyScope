class Market < ApplicationRecord
  has_one :risk_score
  has_many :disputes
  has_many :clarifications
end
