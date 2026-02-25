class CreateMarkets < ActiveRecord::Migration[8.0]
  def change
    create_table :markets do |t|
      t.string :polymarket_id
      t.string :question
      t.text :resolution_criteria
      t.string :category
      t.datetime :end_date
      t.string :status
      t.decimal :yes_price
      t.decimal :no_price
      t.decimal :volume

      t.timestamps
    end
  end
end
