# frozen_string_literal: true

module Reports
  # Renders the result of Reports::EmployeeEarningsQuery#call as a CSV document.
  #
  # Each row is one employee. After the fixed +id_code+, +full_name+ and
  # +total_salary+ columns, every dynamic department/position column follows in
  # the order returned by the query.
  class EmployeeEarningsCsvExporter
    include Reports::CsvFormatting

    # @param result [Hash] output of Reports::EmployeeEarningsQuery#call
    def initialize(result)
      @columns = result.fetch(:columns)
      @rows = result.fetch(:rows)
      @totals = result.fetch(:totals)
    end

    def call
      build_csv do |csv|
        csv << header
        @rows.each { |row| csv << row_values(row) }
        csv << totals_row if @rows.any?
      end
    end

    private

    def header
      fixed_headers + @columns.map { |column| csv_text(column[:label]) }
    end

    def fixed_headers
      [
        I18n.t('reports.earnings.id_code'),
        I18n.t('reports.earnings.full_name'),
        I18n.t('reports.earnings.total_salary')
      ]
    end

    def row_values(row)
      fixed_row_values(row) + @columns.map { |column| csv_money(amount_for(row, column)) }
    end

    def fixed_row_values(row)
      [csv_text(row[:id_code]), csv_text(row[:full_name]), csv_money(row[:total_salary])]
    end

    def totals_row
      [csv_text(I18n.t('reports.earnings.total')), '', csv_money(@totals[:salary])] +
        Array.new(@columns.size, '')
    end

    def amount_for(row, column)
      row[:earnings][column[:key]]
    end
  end
end
