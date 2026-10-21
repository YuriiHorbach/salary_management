# frozen_string_literal: true

require 'bigdecimal'

class HistoricalDataImporter
  # Parses the loosely formatted values that historical CSV files contain.
  module ValueParser
    module_function

    def cents(value)
      return 0 if value.nil? || value.to_s.strip.empty?

      normalized = value.to_s.tr("\u00A0", ' ').strip.gsub(/\s+/, '').tr(',', '.')
      normalized = normalized.delete('^0-9.\-')

      (BigDecimal(normalized) * 100).round
    rescue ArgumentError, TypeError
      0
    end

    def period(value)
      raw = value.to_s.strip
      return if raw.blank?

      date = if raw.match?(/\A\d{4}-\d{2}\z/)
               Date.strptime("#{raw}-01", '%Y-%m-%d')
             else
               date(raw)
             end

      date&.beginning_of_month
    end

    def date(value)
      raw = value.to_s.strip
      return if raw.blank?

      if raw.match?(/\A\d{4}-\d{2}-\d{2}/)
        Date.iso8601(raw[0, 10])
      elsif raw.match?(/\A\d{2}\.\d{2}\.\d{4}\z/)
        Date.strptime(raw, '%d.%m.%Y')
      else
        Date.parse(raw)
      end
    rescue ArgumentError
      nil
    end
  end
end
