# frozen_string_literal: true

module Reports
  class FourDfCsvExporter
    include Reports::CsvFormatting

    SALARY_INCOME_SIGN = '101'

    HEADERS = %w[
      TIN,C,10
      S_NAR,N,14,2
      S_DOX,N,14,2
      S_TAXN,N,14,2
      S_TAXP,N,14,2
      A051,N,12,2
      A05,N,12,2
      OZN_DOX,N,3
      D_PRIYN,D
      D_ZVILN,D
      OZN_PILG,C,2
      OZNAKA,C,1
      R3_TIN,C,10
      DOGNUM,C,10
      DOGDATE,D
      D_DEADLINE,D
      GRANT_DEST
      DATE_EXEC,D
      GRANT_SUM
      FACT,N,14,2
      TAB2_A91,N,1
      TAB2_A9,N,14
      TAB2_A101,N,1
      TAB2_A10,N,14
      R3_OZN,N,1,0
    ].freeze

    def initialize(rows)
      @rows = rows
    end

    def call
      build_csv do |csv|
        csv << HEADERS
        @rows.each { |row| csv << data_row(row) }
      end
    end

    private

    def data_row(row)
      tin = normalize_tin(row.tin)
      gross = hryvnia(row.gross_cents.to_i)
      income_tax = hryvnia(row.income_tax_cents.to_i)
      military_tax = hryvnia(row.military_tax_cents.to_i)
      pilg = row.pilg.to_s

      [
        csv_text(tin),           # TIN
        csv_money(gross),        # S_NAR
        csv_money(gross),        # S_DOX
        csv_money(income_tax),   # S_TAXN
        csv_money(income_tax),   # S_TAXP
        csv_money(military_tax), # A051
        csv_money(military_tax), # A05
        SALARY_INCOME_SIGN,      # OZN_DOX
        '',                      # D_PRIYN (no source in schema)
        '',                      # D_ZVILN (no source in schema)
        pilg,                    # OZN_PILG (from employee flags)
        '',                      # OZNAKA (kept empty per import spec)
        '',                      # R3_TIN (kept empty per import spec)
        '',                      # DOGNUM
        '',                      # DOGDATE
        '',                      # D_DEADLINE
        '',                      # GRANT_DEST
        '',                      # DATE_EXEC
        '',                      # GRANT_SUM
        '',                      # FACT (no source in schema)
        '',                      # TAB2_A91
        '',                      # TAB2_A9
        '',                      # TAB2_A101
        '',                      # TAB2_A10
        ''                       # R3_OZN
      ]
    end

    def hryvnia(cents)
      cents / 100.0
    end

    def normalize_tin(value)
      text = value.to_s.strip
      text.match?(/\A\d{1,10}\z/) ? text.rjust(10, '0') : text
    end
  end
end
