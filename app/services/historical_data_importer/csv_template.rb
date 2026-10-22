# frozen_string_literal: true

require 'csv'

class HistoricalDataImporter
  # Builds the header-only CSV template offered on the import page, so users can
  # download the expected columns, fill in data rows and upload the file back.
  #
  # Columns are derived from +HistoricalDataImporter::HEADER_ALIASES+, which keeps
  # the template in sync with the headers the importer accepts.
  module CsvTemplate
    module_function

    # Canonical column names accepted in a CSV file, in template order.
    #
    # @return [Array<String>] de-duplicated values of +HEADER_ALIASES+
    def headers
      HistoricalDataImporter::HEADER_ALIASES.values.uniq
    end

    # @return [String] a single CSV line with +headers+ and no data rows
    def to_csv
      CSV.generate_line(headers)
    end
  end
end
