# frozen_string_literal: true

# Snapshots resolution_criteria for active markets; detects changes and creates
# MarketDescriptionSnapshot and Clarification records. Feeds Factors 1, 2, 4, 5.
class DescriptionSnapshotJob < ApplicationJob
  queue_as :default

  def perform
    scope = Market.with_volume.where(status: "active")
    scope.find_each do |market|
      snapshot_market(market)
    end
  rescue StandardError => e
    Rails.logger.error("[DescriptionSnapshotJob] #{e.message}")
    raise
  end

  private

  def snapshot_market(market)
    current_text = market.resolution_criteria.to_s
    description_hash = Digest::SHA256.hexdigest(current_text)

    latest = market.market_description_snapshots.order(snapshot_at: :desc).first
    return if latest && latest.description_hash == description_hash

    prev_text = latest&.description_text.to_s
    result = DescriptionChangeDetector.detect(prev_text, current_text)

    market.market_description_snapshots.create!(
      description_text: current_text,
      description_hash: description_hash,
      snapshot_at: Time.current,
      detected_change_type: result[:magnitude],
      edit_distance_ratio: result[:edit_ratio]
    )

    return unless latest.present?

    diff_html = Diffy::Diff.new(prev_text, current_text).to_s(:diff_html)
    market.clarifications.create!(
      previous_text: prev_text,
      new_text: current_text,
      diff_html: diff_html,
      detected_at: Time.current
    )
  end
end
