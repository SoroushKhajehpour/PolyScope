# frozen_string_literal: true

# Phase 2 schema change (see doc/markets_schema_audit_phase2.md).
# ADD: event_id, event_question, event_image.
# REMOVE: image_url, market_type, outcomes, min_value, max_value, current_value, group_id, yes_price, no_price.

class Phase2MarketsEventColumnsAndCleanup < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :event_id, :string unless column_exists?(:markets, :event_id)
    add_column :markets, :event_question, :string unless column_exists?(:markets, :event_question)
    add_column :markets, :event_image, :string unless column_exists?(:markets, :event_image)
    add_index :markets, :event_id, if_not_exists: true

    remove_column :markets, :image_url, :string if column_exists?(:markets, :image_url)
    remove_column :markets, :market_type, :string if column_exists?(:markets, :market_type)
    remove_column :markets, :outcomes, :jsonb if column_exists?(:markets, :outcomes)
    remove_column :markets, :min_value, :decimal, precision: 20, scale: 6 if column_exists?(:markets, :min_value)
    remove_column :markets, :max_value, :decimal, precision: 20, scale: 6 if column_exists?(:markets, :max_value)
    remove_column :markets, :current_value, :decimal, precision: 20, scale: 6 if column_exists?(:markets, :current_value)
    remove_column :markets, :group_id, :string if column_exists?(:markets, :group_id)
    remove_column :markets, :yes_price, :decimal if column_exists?(:markets, :yes_price)
    remove_column :markets, :no_price, :decimal if column_exists?(:markets, :no_price)
  end
end
