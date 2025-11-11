# frozen_string_literal: true

class AddTaxesToSalaries < ActiveRecord::Migration[8.0]
  def change
    add_column :salaries, :income_tax_cents, :integer, default: 0, null: false
    add_column :salaries, :military_tax_cents, :integer, default: 0, null: false
    add_column :salaries, :net_amount_cents, :integer, default: 0, null: false
  end
end
