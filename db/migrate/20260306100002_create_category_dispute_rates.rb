# frozen_string_literal: true

class CreateCategoryDisputeRates < ActiveRecord::Migration[8.0]
  def change
    create_table :category_dispute_rates, if_not_exists: true do |t|
      t.string :category_slug, null: false
      t.integer :total_markets, null: false, default: 0
      t.integer :disputed_count, null: false, default: 0
      t.decimal :dispute_rate_pct, precision: 8, scale: 4
      t.datetime :last_updated_at
      t.datetime :data_window_start
      t.datetime :data_window_end

      t.timestamps
    end

    add_index :category_dispute_rates, :category_slug, unique: true, if_not_exists: true
  end
end
