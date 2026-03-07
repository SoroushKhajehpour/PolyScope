# frozen_string_literal: true

class MarketDescriptionSnapshot < ApplicationRecord
  belongs_to :market

  validates :description_text, presence: true
  validates :description_hash, presence: true
  validates :snapshot_at, presence: true
  validates :detected_change_type, inclusion: { in: %w[minor moderate major critical], allow_nil: true }
end
