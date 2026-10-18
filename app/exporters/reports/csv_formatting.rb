# frozen_string_literal: true

require 'csv'

module Reports
  # Shared helpers for rendering report values safely into CSV documents.
  module CsvFormatting
    BOM = "\uFEFF"
    DELIMITER = ';'

    FORMULA_PREFIXES = ['=', '+', '-', '@', "\t", "\r"].freeze

    def csv_money(value)
      format('%.2f', value || 0).tr('.', ',')
    end

    def csv_text(value)
      return '' if value.nil?

      text = value.to_s
      FORMULA_PREFIXES.include?(text[0]) ? "'#{text}" : text
    end

    def build_csv(&block)
      BOM + CSV.generate(col_sep: DELIMITER, &block)
    end
  end
end
