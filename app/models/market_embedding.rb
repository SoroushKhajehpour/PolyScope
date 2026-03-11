# frozen_string_literal: true

class MarketEmbedding < ApplicationRecord
  belongs_to :market

  validates :embedding_model, presence: true
  validates :embedded_text_hash, presence: true

  # Nearest neighbors by cosine distance, same category. Excludes one market.
  # @param vector [Pgvector::Vector, Array]
  # @param exclude_market_id [Integer]
  # @param category [String, nil]
  # @param limit [Integer]
  # @param max_distance [Float] cosine distance (1 - similarity); e.g. 0.30 for similarity ≥ 0.70
  # @return [ActiveRecord::Relation]
  def self.nearest_same_category(vector, exclude_market_id:, category:, limit: 20, max_distance: 0.30)
    vec = vector.is_a?(Pgvector::Vector) ? vector : Pgvector::Vector.new(vector)
    rel = joins(:market).where.not(market_id: exclude_market_id)
    rel = if category.blank?
      rel.where("markets.category IS NULL OR markets.category = ''")
    else
      rel.where(markets: { category: category })
    end
    rel.where("embedding_vector <=> ? <= ?", vec, max_distance)
       .order("embedding_vector <=> ?", vec)
       .limit(limit)
  end
end
