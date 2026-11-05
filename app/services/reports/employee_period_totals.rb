# frozen_string_literal: true

module Reports
  class EmployeePeriodTotals
    def self.call(salary:, vacation:, sick:, employee:, settings: nil)
      new(salary: salary, vacation: vacation, sick: sick,
          employee: employee, settings: settings).call
    end

    def initialize(salary:, vacation:, sick:, employee:, settings:)
      @salary = salary
      @vacation = vacation
      @sick = sick
      @employee = employee
      @settings = settings
    end

    def call
      combined_gross_cents = @salary[:gross_cents] + @vacation[:gross_cents]
      tax = Reports::SalaryVacationTaxCalculator.call(
        employee: @employee,
        gross_cents: combined_gross_cents,
        settings: @settings
      )

      {
        combined_gross_cents: combined_gross_cents,
        combined_income_tax_cents: tax[:income_tax_cents],
        combined_military_tax_cents: tax[:military_tax_cents],
        gross_cents: combined_gross_cents + @sick[:gross_cents],
        income_tax_cents: tax[:income_tax_cents] + @sick[:income_tax_cents],
        military_tax_cents: tax[:military_tax_cents] + @sick[:military_tax_cents],
        net_amount_cents: tax[:net_amount_cents] + @sick[:net_cents],
        psp_sign: tax[:psp_sign]
      }
    end
  end
end
