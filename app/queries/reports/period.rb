# frozen_string_literal: true

module Reports
  # A report period: one calendar month parsed from a +YYYY-MM+ string.
  #
  # The period is the unit used by the period-income aggregates, so reports and
  # CSV exports can select one month without building an explicit date range.
  class Period
    FORMAT = '%Y-%m'
    PATTERN = /\A\d{4}-\d{2}\z/

    attr_reader :date

    delegate :month, :year, to: :date

    # @param value [String, Reports::Period, nil] a +YYYY-MM+ string or a Period
    # @return [Reports::Period, nil] nil when the value is blank or malformed
    def self.parse(value)
      return value if value.is_a?(self)
      return new(value) if !value.is_a?(String) && value.respond_to?(:to_date)
      return if value.blank? || !PATTERN.match?(value.to_s)

      new(Date.strptime(value.to_s, FORMAT))
    rescue ArgumentError, TypeError
      nil
    end

    # Builds a period from any date inside the requested month.
    #
    # @param date [Date, Time, nil] any date inside the month
    # @return [Reports::Period, nil] nil when the date is blank
    def self.from_date(date)
      return if date.blank?

      new(date)
    end

    # @param date [Date, Time] any date inside the month
    def initialize(date)
      @date = date.to_date.beginning_of_month
    end

    # @return [String] the canonical +YYYY-MM+ representation
    def to_s
      date.strftime(FORMAT)
    end
    alias to_param to_s

    # @return [Range<Date>] the first and last day of the month
    def range
      date.all_month
    end
  end
end
