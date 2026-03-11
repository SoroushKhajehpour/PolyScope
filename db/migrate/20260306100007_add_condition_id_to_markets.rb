# frozen_string_literal: true

class AddConditionIdToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :condition_id, :string unless column_exists?(:markets, :condition_id)
    add_index :markets, :condition_id, if_not_exists: true
  end
end
