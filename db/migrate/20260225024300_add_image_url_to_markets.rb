# frozen_string_literal: true

class AddImageUrlToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :image_url, :string
  end
end
