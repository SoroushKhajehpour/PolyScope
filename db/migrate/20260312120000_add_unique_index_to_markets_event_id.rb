# frozen_string_literal: true

class AddUniqueIndexToMarketsEventId < ActiveRecord::Migration[8.0]
  def change
    remove_index :markets, :event_id
    add_index :markets, :event_id, unique: true
  end
end
