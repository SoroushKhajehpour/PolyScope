# frozen_string_literal: true

class AddOutcomesToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :outcomes, :jsonb
  end
end
