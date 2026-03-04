# frozen_string_literal: true

class AddScalarColumnsToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :min_value, :decimal, precision: 20, scale: 6
    add_column :markets, :max_value, :decimal, precision: 20, scale: 6
    add_column :markets, :current_value, :decimal, precision: 20, scale: 6
  end
end
