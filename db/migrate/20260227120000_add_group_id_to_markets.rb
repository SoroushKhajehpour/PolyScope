# frozen_string_literal: true

class AddGroupIdToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :group_id, :string
    add_index :markets, :group_id
  end
end
