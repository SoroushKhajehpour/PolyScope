# frozen_string_literal: true

# One row per event; child market question no longer stored (event_question is the display title).
class RemoveQuestionFromMarkets < ActiveRecord::Migration[8.0]
  def change
    remove_column :markets, :question, :string
  end
end
