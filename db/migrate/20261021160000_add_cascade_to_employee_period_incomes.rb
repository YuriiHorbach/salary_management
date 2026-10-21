# frozen_string_literal: true

# Ensures period aggregates are removed by the database when an employee is
# deleted, even when rows are removed without ActiveRecord callbacks.
class AddCascadeToEmployeePeriodIncomes < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :employee_period_incomes, :employees
    add_foreign_key :employee_period_incomes, :employees, on_delete: :cascade
  end
end
