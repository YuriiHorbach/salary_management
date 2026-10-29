# frozen_string_literal: true

module Reports
  # Calculates taxes for the combined monthly salary and vacation gross of one
  # employee.
  #
  # Reports treat salary and vacation pay as a single taxable amount so the tax
  # social benefit (PSP) and its income threshold are applied to their sum
  # instead of each income type separately. Sick leave is intentionally excluded
  # because it is taxed on its own with a flat rate.
  class SalaryVacationTaxCalculator
    # @param employee [Employee] employee whose tax settings are applied
    # @param gross_cents [Integer] combined salary and vacation gross in cents
    # @param settings [TaxSetting, nil] preloaded settings; loaded once when nil
    # @return [Hash{Symbol => Integer}] +:income_tax_cents+,
    #   +:military_tax_cents+ and +:net_amount_cents+
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
