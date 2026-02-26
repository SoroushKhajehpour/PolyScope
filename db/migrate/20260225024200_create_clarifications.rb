class CreateClarifications < ActiveRecord::Migration[8.0]
  def change
    create_table :clarifications do |t|
      t.references :market, null: false, foreign_key: true
      t.text :previous_text, null: false
      t.text :new_text, null: false
      t.text :diff_html
      t.datetime :detected_at, null: false

      t.timestamps
    end
  end
end
