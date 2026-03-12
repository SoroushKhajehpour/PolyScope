# frozen_string_literal: true

# Factor 6: Similar outcomes (0–10). Vector similarity + issue signals from similar markets.
# Same category, cosine similarity ≥ 0.70, k=20. Weight by similarity; confidence by count; cap 10.
module RiskScorer
  class SimilarOutcomesScorer
    MAX_SCORE = 10
    MIN_SIMILARITY = 0.70
    K_NEAREST = 20

    # Similarity bands → weight multiplier
    SIMILARITY_WEIGHT = {
      (0.90..1.0) => 1.0,
      (0.80...0.90) => 0.7,
      (0.70...0.80) => 0.4
    }.freeze

    # Count of similar markets → confidence multiplier
    CONFIDENCE_MULT = {
      (5..) => 1.0,
      (3..4) => 0.8,
      (1..2) => 0.5
    }.freeze

    class << self
      # @param market [Market]
      # @return [Hash] { score: Integer 0–10, available: Boolean, factor_metadata: { similar_market_ids: [], similar_scores: {} } }
      def call(market)
        me = market.respond_to?(:market_embedding) ? market.market_embedding : nil
        if me.blank? || me.embedding_vector.blank?
          return { score: 0, available: false, factor_metadata: { similar_market_ids: [], similar_scores: {} } }
        end

        vec = me.embedding_vector
        similar = MarketEmbedding.nearest_same_category(vec, exclude_market_id: market.id, category: market.category, limit: K_NEAREST, max_distance: 1.0 - MIN_SIMILARITY)

        similar_market_ids = []
        similar_scores = {}
        raw_sum = 0.0

        similar.each do |other_me|
          other = other_me.market
          similarity = cosine_similarity(vec, other_me.embedding_vector)
          next if similarity < MIN_SIMILARITY

          issue = issue_score(other)
          weight = similarity_weight(similarity)
          contribution = (issue * weight).round(4)
          raw_sum += contribution
          similar_market_ids << other.id
          similar_scores[other.id] = { similarity: similarity, issue: issue, contribution: contribution }
        end

        confidence = confidence_mult(similar_market_ids.size)
        raw = (raw_sum * confidence).round(2)
        score = [[raw, MAX_SCORE].min, 0].max.to_i

        {
          score: score,
          available: true,
          factor_metadata: {
            similar_market_ids: similar_market_ids,
            similar_scores: similar_scores
          }
        }
      end

      private

      def issue_score(market)
        score = 0.0
        disputes = market.respond_to?(:disputes) ? market.disputes.to_a : []
        if disputes.any?
          score += 2.0
          resolution_contrary = disputes.any? { |d| d.proposed_outcome.to_s != d.final_outcome.to_s && d.final_outcome.present? }
          score += 1.5 if resolution_contrary
        end
        clarifications_count = market.respond_to?(:clarifications) ? market.clarifications.size : 0
        score += [clarifications_count * 0.5, 2.0].min
        score.round(2)
      end

      def similarity_weight(similarity)
        SIMILARITY_WEIGHT.each do |range, mult|
          return mult if range.cover?(similarity)
        end
        0.0
      end

      def confidence_mult(count)
        CONFIDENCE_MULT.each do |range, mult|
          return mult if range.cover?(count)
        end
        0.0
      end

      def cosine_similarity(vec_a, vec_b)
        a = vec_a.respond_to?(:to_a) ? vec_a.to_a : vec_a
        b = vec_b.respond_to?(:to_a) ? vec_b.to_a : vec_b
        return 0.0 if a.size != b.size || a.empty?

        dot = a.zip(b).sum { |x, y| x.to_f * y.to_f }
        norm_a = Math.sqrt(a.sum { |x| x.to_f * x.to_f })
        norm_b = Math.sqrt(b.sum { |x| x.to_f * x.to_f })
        return 0.0 if norm_a.zero? || norm_b.zero?

        sim = dot / (norm_a * norm_b)
        sim.clamp(-1.0, 1.0).round(4)
      end
    end
  end
end
