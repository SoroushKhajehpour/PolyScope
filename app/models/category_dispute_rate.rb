# frozen_string_literal: true

class CategoryDisputeRate < ApplicationRecord
  validates :category_slug, presence: true, uniqueness: true
  validates :total_markets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :disputed_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
