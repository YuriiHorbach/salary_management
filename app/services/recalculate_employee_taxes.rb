# frozen_string_literal: true

# Recalculates taxes for the current month after an employee's tax-affecting
# attributes change.
#
# Historical periods are intentionally left untouched. For the current month
# the service refreshes per-record salary taxes and the aggregated
# +EmployeePeriodIncome+ row used by reports.
class RecalculateEmployeeTaxes
  def self.call(employee)
    new(employee).call
  end

  def initialize(employee)
    @employee = employee
    @period = Date.current.beginning_of_month
  end

  def call
    current_period_salaries.find_each do |salary|
      enqueue_recalculation(salary)
    end

    Incomes::PeriodRecalculator.call(
      employee: @employee,
      period: @period,
      income_type: 'salary'
    )
  end

  private

  def current_period_salaries
    @employee.salaries.where(period: @period)
  end

  def enqueue_recalculation(salary)
    TaxCalculationJob.perform_later(salary.id)
  end
end
