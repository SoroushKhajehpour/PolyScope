class CreateWallets < ActiveRecord::Migration[8.0]
  def change
    create_table :wallets, if_not_exists: true do |t|
      t.string :address, null: false
      t.integer :total_votes, default: 0
      t.decimal :accuracy_rate, precision: 5, scale: 4

      t.timestamps
    end

    add_index :wallets, :address, unique: true, if_not_exists: true
  end
end
