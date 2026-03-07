# frozen_string_literal: true

class AddConditionIdToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :condition_id, :string
    add_index :markets, :condition_id
  end
end
