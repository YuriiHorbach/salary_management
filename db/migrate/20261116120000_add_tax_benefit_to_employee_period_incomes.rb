# frozen_string_literal: true

# Stores the tax social benefit (ПСП) that was applied when the period income
# aggregate was calculated. Keeping it on the aggregate preserves the historical
# benefit even after the employee's tax flags change.
class AddTaxBenefitToEmployeePeriodIncomes < ActiveRecord::Migration[8.0]
  def change
    add_column :employee_period_incomes, :tax_benefit, :string
  end
end
