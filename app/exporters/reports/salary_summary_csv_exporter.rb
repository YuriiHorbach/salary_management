# frozen_string_literal: true

module Reports
  # Renders the result of Reports::SalarySummaryQuery#call as a CSV document.
  class SalarySummaryCsvExporter
    include Reports::CsvFormatting

    def initialize(result)
      @brigades = result.fetch(:brigades)
      @grand_total = result.fetch(:grand_total)
    end

    def call
      build_csv do |csv|
        csv << header
        @brigades.each do |brigade_name, brigade_data|
          brigade_data[:books].each { |book_code, row| csv << book_row(brigade_name, book_code, row) }
          csv << brigade_total_row(brigade_name, brigade_data[:total])
        end
        csv << grand_total_row
      end
    end

    private

    def header
      [I18n.t('reports.csv.brigade'), I18n.t('reports.csv.book'), *column_labels]
    end

    def book_row(brigade_name, book_code, row)
      [csv_text(brigade_name), csv_text(book_code), *money_row(row)]
    end

    def brigade_total_row(brigade_name, total)
      [csv_text(I18n.t('reports.csv.brigade_total', brigade: brigade_name)), '', *money_row(total)]
    end

    def grand_total_row
      [csv_text(I18n.t('reports.csv.total')), '', *money_row(@grand_total)]
    end

    def money_row(row)
      SalarySummaryQuery::COLUMN_KEYS.map { |key| csv_money(row[key]) }
    end

    def column_labels
      SalarySummaryQuery::COLUMN_KEYS.map { |key| I18n.t("reports.summary_columns.#{key}") }
    end
  end
end
