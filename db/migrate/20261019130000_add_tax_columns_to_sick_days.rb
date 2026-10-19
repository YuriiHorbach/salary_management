# frozen_string_literal: true

class AddTaxColumnsToSickDays < ActiveRecord::Migration[8.0]
  def change
    add_column :sick_days, :income_tax_cents, :integer, default: 0, null: false
    add_column :sick_days, :military_tax_cents, :integer, default: 0, null: false
    add_column :sick_days, :net_amount_cents, :integer, default: 0, null: false
  end
end
