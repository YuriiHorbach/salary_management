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
      EmployeeDetailedQuery::COLUMN_LABELS.keys.map { |key| I18n.t("reports.detailed_columns.#{key}") }
    end

    def employee_row(employee)
      EmployeeDetailedQuery::COLUMN_LABELS.each_key.map do |key|
        text_column?(key) ? csv_text(employee[key]) : csv_money(employee[key])
      end
    end

    # One cell per column so trailing text columns stay aligned with the header.
    def totals_row
      EmployeeDetailedQuery::COLUMN_LABELS.each_key.with_index.map do |key, index|
        if index.zero?
          I18n.t('reports.detailed.total')
        elsif text_column?(key)
          ''
        else
          csv_money(@totals[key])
        end
      end
    end

    def text_column?(key)
      EmployeeDetailedQuery::TEXT_COLUMNS.include?(key)
    end
  end
end
