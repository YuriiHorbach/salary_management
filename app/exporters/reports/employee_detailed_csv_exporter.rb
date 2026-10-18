# frozen_string_literal: true

module Reports
  # Renders the result of Reports::EmployeeDetailedQuery#call as a CSV document.
  class EmployeeDetailedCsvExporter
    include Reports::CsvFormatting

    def initialize(result)
      @employees = result.fetch(:employees)
      @totals = result.fetch(:totals)
    end

    def call
      build_csv do |csv|
        csv << header
        @employees.each { |employee| csv << employee_row(employee) }
        csv << totals_row if @employees.any?
      end
    end

    private

    def header
      EmployeeDetailedQuery::COLUMN_LABELS.values
    end

    def employee_row(employee)
      EmployeeDetailedQuery::COLUMN_LABELS.each_key.map do |key|
        text_column?(key) ? csv_text(employee[key]) : csv_money(employee[key])
      end
    end

    def totals_row
      ['Загалом', *Array.new(EmployeeDetailedQuery::TEXT_COLUMNS.size - 1, ''), *money_totals]
    end

    def money_totals
      money_keys.map { |key| csv_money(@totals[key]) }
    end

    def money_keys
      EmployeeDetailedQuery::COLUMN_LABELS.keys - EmployeeDetailedQuery::TEXT_COLUMNS
    end

    def text_column?(key)
      EmployeeDetailedQuery::TEXT_COLUMNS.include?(key)
    end
  end
end
