# frozen_string_literal: true

# Backfills aggregates for salaries, vacations and sick days that existed before
# the employee_period_incomes table was introduced.
class BackfillEmployeePeriodIncomes < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:employee_period_incomes)

    Employee.find_each do |employee|
      periods_for(employee).each do |period|
        EmployeePeriodIncome::INCOME_TYPES.each do |income_type|
          Incomes::PeriodRecalculator.call(employee: employee, period: period, income_type: income_type)
        end
      end
    end
  end

  def down
    # Aggregates are derived data and can be rebuilt with incomes:recalculate.
  end

  private

  def periods_for(employee)
    [
      employee.salaries.pluck(:period),
      employee.vacations.pluck(:period),
      employee.sick_days.pluck(:period)
    ].flatten.compact.map { |period| period.to_date.beginning_of_month }.uniq
  end
end
