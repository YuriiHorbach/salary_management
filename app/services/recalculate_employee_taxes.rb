# frozen_string_literal: true

# Recalculates taxes for the current month after an employee's tax-affecting
# attributes change.
#
# Historical periods are intentionally left untouched. For the current month a
# single +EmployeeTaxRecalculationJob+ is enqueued per employee and period; the
# job refreshes the per-record salary taxes and the aggregated
# +EmployeePeriodIncome+ row used by reports.
class RecalculateEmployeeTaxes
  # @param employee [Employee] employee whose current-month taxes are refreshed
  # @return [void]
  def self.call(employee)
    new(employee).call
  end

  # @param employee [Employee]
  def initialize(employee)
    @employee = employee
    @period = Date.current.beginning_of_month
  end

  # Enqueues one recalculation job when the employee has salaries in the period.
  #
  # @return [void]
  def call
    return unless current_period_salaries.exists?

    EmployeeTaxRecalculationJob.perform_later(@employee.id, @period)
  end

  private

  def current_period_salaries
    @employee.salaries.where(period: @period)
  end
end
