# Vacation payment for an employee.
#
# Per-record taxes are kept for display, while +Incomes::PeriodRecalculator+
# calculates the authoritative taxes on the total vacation amount of a month.
class Vacation < ApplicationRecord
  # Aggregated row used by the monthly vacation report.
  ReportRow = Data.define(:employee_id, :vacations_count, :vacation_cents, :income_tax_cents,
                          :military_tax_cents, :net_cents)

  belongs_to :employee
  belongs_to :department, optional: true

  scope :for_month, ->(month = Date.current) { where(period: month.to_date.all_month) }

  before_validation :calculate_and_assign_taxes, if: :vacation_amount_changed?

  after_destroy :refresh_period_income
  after_save :refresh_period_income

  monetize :vacation_amount_cents
  monetize :income_tax_cents
  monetize :military_tax_cents
  monetize :net_amount_cents

  validates :period, :vacation_amount, presence: true
  validates :vacation_amount, numericality: { greater_than_or_equal_to: 0 }

  def pdfo_amount
    Money.new(income_tax_cents || 0, vacation_amount.currency)
  end

  def military_amount
    Money.new(military_tax_cents || 0, vacation_amount.currency)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[period vacation_amount_cents income_tax_cents military_tax_cents net_amount_cents]
  end

  # Aggregates vacation counts and monetary sums by employee for a report month.
  #
  # The grouping and summing happen in SQL so only the aggregate rows are loaded.
  #
  # @param month_str [String, nil] month in +YYYY-MM+ format
  # @return [Array<ReportRow>] rows with employee id, record count and vacation/tax/net cents;
  #   empty for invalid input
  def self.report_rows_for_month(month_str)
    date = Date.strptime(month_str.to_s, '%Y-%m')
    for_month(date)
      .group(:employee_id)
      .pluck(
        :employee_id,
        Arel.sql('COUNT(*)'),
        Arel.sql('SUM(vacation_amount_cents)'),
        Arel.sql('SUM(income_tax_cents)'),
        Arel.sql('SUM(military_tax_cents)'),
        Arel.sql('SUM(net_amount_cents)')
      )
      .map { |values| build_report_row(*values) }
  rescue Date::Error, TypeError
    []
  end

  # @return [Hash{Integer => Integer}] employee id => vacation record count
  def self.report_for_month(month_str)
    report_rows_for_month(month_str).to_h { |row| [row.employee_id, row.vacations_count] }
  end

  # @return [ReportRow] aggregate row with integer cents
  def self.build_report_row(employee_id, vacations_count, vacation_cents, income_tax_cents,
                            military_tax_cents, net_cents)
    ReportRow.new(
      employee_id:,
      vacations_count:,
      vacation_cents: vacation_cents.to_i,
      income_tax_cents: income_tax_cents.to_i,
      military_tax_cents: military_tax_cents.to_i,
      net_cents: net_cents.to_i
    )
  end
  private_class_method :build_report_row

  private

  def refresh_period_income
    periods = [period]
    periods << period_before_last_save if saved_change_to_period?

    periods.compact.uniq.each do |changed_period|
      Incomes::PeriodRecalculator.call(employee: employee, period: changed_period, income_type: 'vacation')
    end
  end

  def calculate_and_assign_taxes
    return if vacation_amount_cents.blank? || vacation_amount_cents.to_i.zero?

    result = TaxCalculator.call(amount_cents: vacation_amount_cents.to_i, simple: true)

    self.income_tax_cents = result[:income_tax_cents].to_i
    self.military_tax_cents = result[:military_tax_cents].to_i
    self.net_amount_cents = result[:net_amount_cents].to_i
  end

  def vacation_amount_changed?
    will_save_change_to_vacation_amount_cents?
  end
end
