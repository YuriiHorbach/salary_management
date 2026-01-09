# frozen_string_literal: true

class TaxCalculationJob < ApplicationJob
  queue_as :default

  def perform(salary_id)
    salary = Salary.find_by(id: salary_id)
    return unless salary

    salary.with_lock do
      amount_cents = if salary.respond_to?(:amount_cents) && salary.amount_cents.present?
                       salary.amount_cents.to_i
                     else
                       (salary.amount.to_d * 100).to_i
                     end

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
    Rails.logger.error("TaxCalculationJob(#{salary_id}) failed: #{e.class} #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    raise
  end
end
