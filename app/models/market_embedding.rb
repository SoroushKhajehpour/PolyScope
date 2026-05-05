# frozen_string_literal: true

class MarketEmbedding < ApplicationRecord
  belongs_to :market

  validates :embedding_model, presence: true
  validates :embedded_text_hash, presence: true

  # Float array for math / query binding. Handles Pgvector::Vector, Array, or String
  # (Rails often loads vector(3072) as String when the OID is not registered — see boot logs).
  def self.embedding_numeric_components(value)
    case value
    when Pgvector::Vector
      value.to_a
    when Array
      value.map(&:to_f)
    when String
      str = value.strip
      return [] if str.blank?

      Pgvector::Vector.from_text(str).to_a
    else
      []
    end
  rescue StandardError
    []
  end

  # Nearest neighbors by cosine distance, same category. Excludes one market.
  # @param vector [Pgvector::Vector, Array, String] text form e.g. from Pgvector.encode / AR String column
  # @param exclude_market_id [Integer]
  # @param category [String, nil]
  # @param limit [Integer]
  # @param max_distance [Float] cosine distance (1 - similarity); e.g. 0.30 for similarity ≥ 0.70
  # @return [ActiveRecord::Relation]
  def self.nearest_same_category(vector, exclude_market_id:, category:, limit: 20, max_distance: 0.30)
    components = embedding_numeric_components(vector)
    return none if components.empty?

    # Bind the literal text form — ActiveRecord cannot quote Pgvector::Vector for placeholders.
    vec_literal = Pgvector.encode(components)
    rel = joins(:market).where.not(market_id: exclude_market_id)
    rel = if category.blank?
      rel.where("markets.category IS NULL OR markets.category = ''")
    else
      rel.where(markets: { category: category })
    end
    # Rails 8 forbids raw SQL fragments in where/order unless wrapped in Arel.sql (disallow_raw_sql!).
    dist_clause = sanitize_sql_array(["embedding_vector <=> ?::vector", vec_literal])
    filter_clause = sanitize_sql_array(["embedding_vector <=> ?::vector <= ?", vec_literal, max_distance])
    rel.where(Arel.sql(filter_clause))
       .order(Arel.sql(dist_clause))
       .limit(limit)
  end
end
