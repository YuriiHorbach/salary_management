# frozen_string_literal: true

class AddPaindOnToSalaries < ActiveRecord::Migration[7.1]
  def change
    add_column :salaries, :paid_on, :datetime, null: false
  end
end
