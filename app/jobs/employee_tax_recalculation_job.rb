# frozen_string_literal: true

# Recalculates the taxes of one employee for one month in a single job.
#
# Every salary of the employee in the period is refreshed through
# +Salaries::TaxRecalculator+, then the aggregated +EmployeePeriodIncome+ row is
# rebuilt by +Incomes::PeriodRecalculator+. Using one job per employee and
# period avoids enqueueing one job per salary.
class EmployeeTaxRecalculationJob < ApplicationJob
  queue_as :default

  # @param employee_id [Integer] employee whose salaries are recalculated
  # @param period [Date, String] any date inside the target month
  # @return [void]
  def perform(employee_id, period)
    employee = Employee.find_by(id: employee_id)
    return unless employee

    normalized_period = period.to_date.beginning_of_month
    employee.salaries.where(period: normalized_period).find_each do |salary|
      Salaries::TaxRecalculator.call(salary)
    end

    Incomes::PeriodRecalculator.call(
      employee: employee,
      period: normalized_period,
      income_type: 'salary'
    )
  rescue StandardError => e
    Rails.logger.error("EmployeeTaxRecalculationJob(#{employee_id}, #{period}) failed: #{e.message}")
    raise
  end
end
