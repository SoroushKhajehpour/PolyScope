# frozen_string_literal: true

class CreateMarketDescriptionSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :market_description_snapshots do |t|
      t.references :market, null: false, foreign_key: true
      t.text :description_text, null: false
      t.string :description_hash, null: false
      t.datetime :snapshot_at, null: false
      t.string :detected_change_type
      t.decimal :edit_distance_ratio, precision: 5, scale: 4

      t.timestamps
    end

    add_index :market_description_snapshots, [:market_id, :snapshot_at]
  end
end
