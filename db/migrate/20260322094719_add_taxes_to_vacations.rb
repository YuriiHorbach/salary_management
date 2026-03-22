class AddTaxesToVacations < ActiveRecord::Migration[8.0]
  def change
    add_column :vacations, :income_tax_cents, :integer
    add_column :vacations, :military_tax_cents, :integer
    add_column :vacations, :net_amount_cents, :integer
  end
end
