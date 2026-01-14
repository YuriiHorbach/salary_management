# frozen_string_literal: true

class TaxCalculationJob < ApplicationJob
  queue_as :default

  def perform(salary_id)
    salary = Salary.find_by(id: salary_id)
    return unless salary

    salary.employee.reload

    salary.with_lock do
      amount_cents = salary.amount_cents

      res = TaxCalculator.call(
        amount_cents: amount_cents,
        children_count: salary.employee.try(:children_count) || 0,
        disability_group: salary.employee.try(:disability_group) || 0,
        chaes: salary.employee.try(:chaes) || false,
        contract: salary.employee.try(:contract) || false
      )

      salary.update_columns(
        income_tax_cents: res[:income_tax_cents],
        military_tax_cents: res[:military_tax_cents],
        net_amount_cents: res[:net_amount_cents],
        updated_at: Time.current
      )
    end
  rescue StandardError => e
    Rails.logger.error("TaxCalculationJob(#{salary_id}) failed: #{e.message}")
    raise
  end
end
