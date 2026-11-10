# frozen_string_literal: true

module Reports
  class FourDfQuery
    Row = Struct.new(:tin, :gross_cents, :income_tax_cents, :military_tax_cents, :pilg,
                     keyword_init: true)

    ZERO_INCOME = {
      gross_cents: 0, income_tax_cents: 0, military_tax_cents: 0, net_cents: 0
    }.freeze

    # @param period [Reports::Period, String, nil] optional +YYYY-MM+ period
    # @param year [String, Integer, nil]
    # @param month [String, Integer, nil]
    # @param department [String, Integer, nil]
    def initialize(period: nil, year: nil, month: nil, department: nil)
      selected_period = Reports::Period.parse(period)
      @year = selected_period&.year || year.presence
      @month = selected_period&.month || month.presence
      @department = department.presence
    end

    def call
      incomes = period_incomes
      return [] if incomes.empty?

      scoped_employees(incomes.keys)
        .filter_map { |employee| build_row(employee, incomes.fetch(employee.id)) }
    end

    private

    def scoped_employees(employee_ids)
      scope = Employee.where(id: employee_ids)
      if @department
        scope = scope.joins(department_employees: :department)
                     .where(departments: { id: @department.to_i })
                     .distinct
      end

      scope.order(:last_name, :first_name, :id_code)
    end

    def period_incomes
      @period_incomes ||= begin
        scope = EmployeePeriodIncome.where(employee_id: Employee.select(:id))
        scope = scope.where('EXTRACT(YEAR FROM period) = ?', @year.to_i) if @year
        scope = scope.where('EXTRACT(MONTH FROM period) = ?', @month.to_i) if @month

        scope.group_by(&:employee_id).transform_values do |rows|
          rows.group_by(&:income_type).transform_values do |typed_rows|
            typed_rows.map { |row| cents_hash(row) }
                      .reduce(ZERO_INCOME) { |total, cents| total.merge(cents) { |_key, a, b| a + b } }
          end
        end
      end
    end

    def cents_hash(row)
      {
        gross_cents: row.gross_cents.to_i,
        income_tax_cents: row.income_tax_cents.to_i,
        military_tax_cents: row.military_tax_cents.to_i,
        net_cents: row.net_amount_cents.to_i
      }
    end

    def build_row(employee, incomes)
      totals = Reports::EmployeePeriodTotals.call(
        salary: incomes.fetch('salary', ZERO_INCOME),
        vacation: incomes.fetch('vacation', ZERO_INCOME),
        sick: incomes.fetch('sick_day', ZERO_INCOME),
        employee: employee,
        settings: TaxSetting.current
      )
      return nil if totals[:gross_cents].zero? &&
                    totals[:income_tax_cents].zero? &&
                    totals[:military_tax_cents].zero?

      Row.new(tin: employee.id_code.to_s,
              gross_cents: totals[:gross_cents],
              income_tax_cents: totals[:income_tax_cents],
              military_tax_cents: totals[:military_tax_cents],
              pilg: totals[:psp_sign])
    end
  end
end
