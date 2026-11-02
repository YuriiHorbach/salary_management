# frozen_string_literal: true

module Salaries
  # Builds the rows of the "period totals" table on the employee salaries page.
  #
  # Groups an employee's +EmployeePeriodIncome+ records by period (newest
  # first), keeps the three income types of each period apart and precomputes
  # the per-column totals in cents, so the view only renders values and never
  # groups, indexes or sums records itself.
  class PeriodIncomeTable
    # One rendered table row: the income records of a single period plus the
    # totals summed across those records (all amounts in cents).

    Row = Struct.new(:period, :salary, :vacation, :sick,
                     :gross_total, :income_tax_total, :military_tax_total,
                     keyword_init: true)

    # @param incomes [Enumerable<EmployeePeriodIncome>] records of one employee
    def initialize(incomes)
      @incomes = incomes
    end

    # @return [Array<Row>] one row per period, newest period first
    def call
      @incomes.group_by(&:period).sort_by(&:first).reverse_each.map do |period, records|
        build_row(period, records)
      end
    end

    private

    def build_row(period, records)
      by_type = records.index_by(&:income_type)
      salary = by_type['salary']
      vacation = by_type['vacation']
      sick = by_type['sick_day']

      Row.new(
        period: period,
        salary: salary,
        vacation: vacation,
        sick: sick,
        gross_total: sum_cents(salary, vacation, sick, :gross_cents),
        income_tax_total: sum_cents(salary, vacation, sick, :income_tax_cents),
        military_tax_total: sum_cents(salary, vacation, sick, :military_tax_cents)
      )
    end

    # Sums one cents attribute across the records, counting missing types as 0.
    #
    # @param records [Array<EmployeePeriodIncome, nil>] income types of a period
    # @param attribute [Symbol] cents column to sum
    # @return [Integer] total in cents
    def sum_cents(*records, attribute)
      records.sum { |record| record&.public_send(attribute).to_i }
    end
  end
end
