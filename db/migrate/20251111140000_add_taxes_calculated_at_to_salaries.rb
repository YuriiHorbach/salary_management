# frozen_string_literal: true

class AddTaxesCalculatedAtToSalaries < ActiveRecord::Migration[8.0]
  def change
    add_column :salaries, :taxes_calculated_at, :datetime
  end
end
