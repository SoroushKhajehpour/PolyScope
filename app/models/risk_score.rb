# frozen_string_literal: true

class RiskScore < ApplicationRecord
  belongs_to :market

  validates :score, presence: true, numericality: { only_integer: true, in: 0..100 }
  validates :level, presence: true, inclusion: { in: %w[low medium high critical] }

  # Level from config for a given score (0–100). Use when mapping without persisting.
  def self.level_for_score(score)
    RiskScoringConfig.level_for_score(score)
  end
end
