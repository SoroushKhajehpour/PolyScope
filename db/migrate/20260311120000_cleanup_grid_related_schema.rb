# frozen_string_literal: true

class CleanupGridRelatedSchema < ActiveRecord::Migration[8.0]
  def up
    # Old grid/filter UI artifacts (drop only when present).
    drop_table :market_filters, if_exists: true
    drop_table :saved_filters, if_exists: true

    remove_column :markets, :display_rank if column_exists?(:markets, :display_rank)
    remove_column :markets, :grid_position if column_exists?(:markets, :grid_position)

    remove_column :risk_scores, :display_badge if column_exists?(:risk_scores, :display_badge)
    remove_column :risk_scores, :badge_color if column_exists?(:risk_scores, :badge_color)
  end

  def down
    # Intentionally no-op: this migration only removes optional legacy UI artifacts.
  end
end
