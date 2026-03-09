# frozen_string_literal: true

# Builds CategoryDisputeRate from UMA dispute data joined to markets by condition_id.
# Uses Bayesian smoothing: (n * rate + 10 * global_rate) / (n + 10).
class CategoryDisputeRateBuilder
  BAYESIAN_PRIOR_WEIGHT = 10

  # @param requests [Array<Hash>] Each hash: { condition_id: String, disputed: Boolean }
  # @param window_start [Time, nil] Optional data window start for reporting
  # @param window_end [Time, nil] Optional data window end for reporting
  def initialize(requests:, window_start: nil, window_end: nil)
    @requests = requests
    @window_start = window_start
    @window_end = window_end
  end

  def build
    condition_to_disputed = @requests.to_h { |r| [r[:condition_id].to_s, r[:disputed]] }
    condition_ids = condition_to_disputed.keys
    return if condition_ids.empty?

    markets = Market.where(condition_id: condition_ids).where.not(condition_id: nil)
    return if markets.empty?

    # Per-category: total markets (from our DB that appear in UMA), disputed count
    by_category = Hash.new { |h, k| h[k] = { total: 0, disputed: 0 } }
    markets.find_each do |m|
      slug = category_slug(m.category)
      next if slug.blank?

      disputed = condition_to_disputed[m.condition_id]
      by_category[slug][:total] += 1
      by_category[slug][:disputed] += 1 if disputed
    end

    global_total = by_category.sum { |_, v| v[:total] }
    global_disputed = by_category.sum { |_, v| v[:disputed] }
    global_rate_pct = global_total.positive? ? (100.0 * global_disputed / global_total) : 0.0

    now = Time.current
    rows = by_category.map do |category_slug, counts|
      total = counts[:total]
      disputed = counts[:disputed]
      raw_rate_pct = total.positive? ? (100.0 * disputed / total) : 0.0
      smoothed_pct = smooth(raw_rate_pct, total, global_rate_pct)
      {
        category_slug: category_slug,
        total_markets: total,
        disputed_count: disputed,
        dispute_rate_pct: smoothed_pct.round(4),
        last_updated_at: now,
        data_window_start: @window_start,
        data_window_end: @window_end,
        updated_at: now,
        created_at: now
      }
    end
    return if rows.empty?

    CategoryDisputeRate.upsert_all(
      rows,
      unique_by: :category_slug,
      update_only: %w[total_markets disputed_count dispute_rate_pct last_updated_at data_window_start data_window_end updated_at]
    )
  end

  private

  def category_slug(category)
    return nil if category.blank?
    category.to_s.parameterize.presence
  end

  def smooth(category_rate_pct, n, global_rate_pct)
    return category_rate_pct if n <= 0
    # (n * rate + BAYESIAN_PRIOR_WEIGHT * global_rate) / (n + BAYESIAN_PRIOR_WEIGHT)
    num = n * category_rate_pct + BAYESIAN_PRIOR_WEIGHT * global_rate_pct
    den = n + BAYESIAN_PRIOR_WEIGHT
    num / den
  end
end
