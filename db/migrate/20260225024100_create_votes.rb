class CreateVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :votes do |t|
      t.references :dispute, null: false, foreign_key: true
      t.references :wallet, null: false, foreign_key: true
      t.string :vote_direction, null: false
      t.decimal :token_amount, precision: 20, scale: 6

      t.timestamps
    end
  end
end
