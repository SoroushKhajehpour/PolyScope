# frozen_string_literal: true

# Phase 2 schema change (see doc/markets_schema_audit_phase2.md).
# ADD: event_id, event_question, event_image.
# REMOVE: image_url, market_type, outcomes, min_value, max_value, current_value, group_id, yes_price, no_price.

class Phase2MarketsEventColumnsAndCleanup < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :event_id, :string
    add_column :markets, :event_question, :string
    add_column :markets, :event_image, :string
    add_index :markets, :event_id

    remove_column :markets, :image_url, :string
    remove_column :markets, :market_type, :string
    remove_column :markets, :outcomes, :jsonb
    remove_column :markets, :min_value, :decimal, precision: 20, scale: 6
    remove_column :markets, :max_value, :decimal, precision: 20, scale: 6
    remove_column :markets, :current_value, :decimal, precision: 20, scale: 6
    remove_column :markets, :group_id, :string
    remove_column :markets, :yes_price, :decimal
    remove_column :markets, :no_price, :decimal
  end
end
