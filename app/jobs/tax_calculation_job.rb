# frozen_string_literal: true

# Recalculates the stored tax columns of a single salary record.
#
# Bulk recalculation for an employee and period is performed by
# +EmployeeTaxRecalculationJob+, which reuses +Salaries::TaxRecalculator+.
class TaxCalculationJob < ApplicationJob
  queue_as :default

  # @param salary_id [Integer] salary to recalculate
  # @return [void]
  def perform(salary_id)
    salary = Salary.find_by(id: salary_id)
    return unless salary

    Salaries::TaxRecalculator.call(salary)
  rescue StandardError => e
    Rails.logger.error("TaxCalculationJob(#{salary_id}) failed: #{e.message}")
    raise
  end
end
