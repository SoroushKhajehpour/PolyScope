# frozen_string_literal: true

class AddMarketTypeToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :market_type, :string
  end
end
