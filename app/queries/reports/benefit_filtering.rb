# frozen_string_literal: true

module Reports
  # Shared employee filtering by the tax benefit snapshot stored on
  # +EmployeePeriodIncome+ for the selected period.
  #
  # Benefit codes match the values rendered in the detailed report:
  # +01+ (basic), +02+ (increased 150%), +03+ (UBD), +04+ (children) and
  # +none+ for employees without an applied benefit.
  module BenefitFiltering
    private

    # @param scope [ActiveRecord::Relation] employee or salary relation
    # @param code [String, nil] report code +01+..+04+, +none+, or blank
    # @param range [Range<Date>] months already selected by the report
    # @param column [Symbol] employee FK on +scope+ (+:id+ for Employee)
    # @return [ActiveRecord::Relation] scope narrowed to matching employees
    def filter_by_benefit(scope, code, range, column: :id)
      return scope if code.blank?

      incomes = EmployeePeriodIncome.salary_for_period(range)

      if code.to_s == EmployeePeriodIncome::NO_BENEFIT
        return scope.where.not(column => incomes.where.not(tax_benefit: nil).select(:employee_id))
      end

      kinds = EmployeePeriodIncome::TAX_BENEFIT_KINDS_BY_CODE[code.to_s]
      return scope if kinds.blank?

      scope.where(column => incomes.where(tax_benefit: kinds).select(:employee_id))
    end
  end
end
