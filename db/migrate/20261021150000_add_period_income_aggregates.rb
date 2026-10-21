# frozen_string_literal: true

# Adds the position reference to salaries and creates the per-period income
# aggregates used for tax calculations and reports.
class AddPeriodIncomeAggregates < ActiveRecord::Migration[8.0]
  def change
    add_reference :salaries, :position, foreign_key: { on_delete: :nullify }, index: true

    remove_index :salaries, %i[employee_id period]
    add_index :salaries, %i[employee_id period position_id],
              unique: true,
              where: 'position_id IS NOT NULL',
              name: 'index_salaries_unique_position_per_period'
    add_index :salaries, %i[employee_id period department_id],
              unique: true,
              where: 'position_id IS NULL',
              name: 'index_salaries_unique_department_per_period'

    create_table :employee_period_incomes do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :period, null: false
      t.string :income_type, null: false
      t.integer :gross_cents, null: false, default: 0
      t.integer :income_tax_cents, null: false, default: 0
      t.integer :military_tax_cents, null: false, default: 0
      t.integer :net_amount_cents, null: false, default: 0
      t.string :tax_settings_digest
      t.timestamps
    end

    add_index :employee_period_incomes, %i[employee_id period income_type],
              unique: true,
              name: 'index_employee_period_incomes_unique'
  end
end
