# frozen_string_literal: true

module Reports
  class SalaryVacationTaxCalculator
    def self.call(employee:, gross_cents:, settings: nil)
      TaxCalculator.call(
        amount_cents: gross_cents.to_i,
        children_count: employee.children_count.to_i,
        disability_group: employee.disability_group.to_i,
        chaes: employee.chaes || false,
        contract: employee.contract || false,
        settings: settings
      )
    end
  end
end
