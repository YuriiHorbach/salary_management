# frozen_string_literal: true

# Aggregates salary totals for the salary report.
#
# The overall totals and the department breakdown are each fetched with one
# query. The SQL sums the source columns directly, so a relation carrying
# +distinct+ cannot turn the aggregate into +SUM(DISTINCT ...)+ and undercount
# duplicate salary amounts.
class SalaryReportService
  TOTALS_SQL = {
    gross: 'COALESCE(SUM(salaries.amount_cents), 0)',
    income_tax: 'COALESCE(SUM(salaries.income_tax_cents), 0)',
    military_tax: 'COALESCE(SUM(salaries.military_tax_cents), 0)',
    net: 'COALESCE(SUM(salaries.net_amount_cents), 0)'
  }.freeze

  DEPARTMENT_TOTALS_SQL = {
    gross: 'COALESCE(SUM(salaries.amount_cents), 0)',
    net: 'COALESCE(SUM(salaries.net_amount_cents), 0)',
    pdfo: 'COALESCE(SUM(salaries.income_tax_cents), 0)',
    military_tax: 'COALESCE(SUM(salaries.military_tax_cents), 0)'
  }.freeze

  # @param salary_records [ActiveRecord::Relation<Salary>]
  def initialize(salary_records)
    @records = salary_records
  end

  # @return [Hash{Symbol => Integer}] gross, income tax, military tax, and net totals
  def call
    values = @records.pick(*aggregate_expressions(TOTALS_SQL)) ||
             Array.new(TOTALS_SQL.size, 0)

    TOTALS_SQL.keys.zip(values).to_h
  end

  # @return [Hash{String => Hash{Symbol => Integer}}] totals keyed by department name
  def department_totals
    rows = @records
           .joins(:department)
           .group('departments.name')
           .pluck('departments.name', *aggregate_expressions(DEPARTMENT_TOTALS_SQL))

    rows.to_h do |department_name, *values|
      [department_name, DEPARTMENT_TOTALS_SQL.keys.zip(values).to_h]
    end
  end

  private

  # @param columns [Hash{Symbol => String}]
  # @return [Array<Arel::Nodes::SqlLiteral>]
  def aggregate_expressions(columns)
    columns.values.map { |sql| Arel.sql(sql) }
  end
end
