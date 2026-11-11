# frozen_string_literal: true

# Sick leave payment split between the social fund and the employer.
#
# Per-record taxes are kept for display, while +Incomes::PeriodRecalculator+
# calculates the authoritative taxes on the total sick-day amount of a month.
class SickDay < ApplicationRecord
  # Aggregated row used by the current month summary on the entry page.
  SummaryRow = Data.define(:employee, :sick_days_count)

  # Aggregated row used by the monthly sick day report.
  ReportRow = Data.define(:employee_id, :sick_days_count, :pfu_cents, :enterprise_cents, :total_cents)

  # Largest amount representable by the 4-byte integer money columns.
  MAX_AMOUNT_CENTS = (2**31) - 1

  belongs_to :employee
  belongs_to :department, optional: true

  scope :for_month, ->(month = Date.current) { where(period: month.to_date.all_month) }
  scope :current_month_entries, -> { for_month(Date.current) }

  before_validation :assign_taxes, if: :amounts_changed?

  after_destroy :refresh_period_income
  after_save :refresh_period_income

  monetize :pfu_amount_cents
  monetize :enterprise_amount_cents
  monetize :income_tax_cents
  monetize :military_tax_cents
  monetize :net_amount_cents

  alias set_pfu_amount pfu_amount=
  alias set_enterprise_amount enterprise_amount=

  # A blank amount input means zero, not an invalid number.
  def pfu_amount=(value)
    assign_amount(:pfu_amount, value)
  end

  def enterprise_amount=(value)
    assign_amount(:enterprise_amount, value)
  end

  validates :period, presence: true
  validates :pfu_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :enterprise_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :amounts_within_database_range

  def total_amount
    pfu_amount + enterprise_amount
  end

  # Aggregates sick days for the given month by employee in a single grouped query.
  #
  # @param month [Date, Time] any date inside the requested month
  # @return [Array(Array<SummaryRow>, Integer)] rows sorted by employee name and the grand total
  def self.current_month_summary(month = Date.current)
    counts = for_month(month).group(:employee_id).count
    employees = Employee.where(id: counts.keys).index_by(&:id)

    rows = counts.filter_map do |employee_id, sick_days_count|
      employee = employees[employee_id]
      SummaryRow.new(employee: employee, sick_days_count: sick_days_count) if employee
    end

    [rows.sort_by { |row| row.employee.full_name }, counts.values.sum]
  end

  # Aggregates sick day counts and monetary sums by employee for a report month.
  #
  # The grouping and summing happen in SQL so only the aggregate rows are loaded.
  #
  # @param month_str [String, nil] month in +YYYY-MM+ format
  # @return [Array<ReportRow>] rows with employee id, count and PFU/enterprise cents;
  #   empty for invalid input
  def self.report_rows_for_month(month_str)
    date = Date.strptime(month_str.to_s, '%Y-%m')
    for_month(date)
      .group(:employee_id)
      .pluck(
        :employee_id,
        Arel.sql('COUNT(*)'),
        Arel.sql('SUM(pfu_amount_cents)'),
        Arel.sql('SUM(enterprise_amount_cents)')
      )
      .map { |values| build_report_row(*values) }
  rescue Date::Error, TypeError
    []
  end

  # @return [ReportRow] aggregate row with integer cents
  def self.build_report_row(employee_id, sick_days_count, pfu_cents, enterprise_cents)
    pfu_cents = pfu_cents.to_i
    enterprise_cents = enterprise_cents.to_i

    ReportRow.new(employee_id:, sick_days_count:, pfu_cents:, enterprise_cents:,
                  total_cents: pfu_cents + enterprise_cents)
  end
  private_class_method :build_report_row

  # Aggregates sick day counts by employee for a report month.
  #
  # @param month_str [String, nil] month in +YYYY-MM+ format
  # @return [Hash{Integer => Integer}] employee id => sick day count, empty for invalid input
  def self.report_for_month(month_str)
    report_rows_for_month(month_str).to_h { |row| [row.employee_id, row.sick_days_count] }
  end

  # The form submits a month ("YYYY-MM"), while the attribute is cast to Date.
  def period=(value)
    value = Date.strptime(value, '%Y-%m') if value.is_a?(String) && /\A\d{4}-\d{2}\z/.match?(value)
    super
  end

  def pdfo_amount
    Money.new(income_tax_cents || 0, pfu_amount.currency)
  end

  def military_amount
    Money.new(military_tax_cents || 0, pfu_amount.currency)
  end

  private

  # Assigns a monetized amount, replacing values that would overflow the integer column
  # with zero and remembering the overflow so validation can report it.
  def assign_amount(attribute, value)
    value = value.presence || 0
    public_send(:"set_#{attribute}", value)

    cents = public_send(:"#{attribute}_cents")
    return instance_variable_set(:"@#{attribute}_overflow", false) if cents.nil? || cents.abs <= MAX_AMOUNT_CENTS

    instance_variable_set(:"@#{attribute}_overflow", true)
    public_send(:"set_#{attribute}", 0)
  rescue ActiveModel::RangeError
    instance_variable_set(:"@#{attribute}_overflow", true)
    public_send(:"set_#{attribute}", 0)
  end

  def amounts_within_database_range
    errors.add(:pfu_amount, :amount_too_large) if @pfu_amount_overflow
    errors.add(:enterprise_amount, :amount_too_large) if @enterprise_amount_overflow
  end

  def refresh_period_income
    periods = [period]
    periods << period_before_last_save if saved_change_to_period?

    periods.compact.uniq.each do |changed_period|
      Incomes::PeriodRecalculator.call(employee: employee, period: changed_period, income_type: 'sick_day')
    end
  end

  def assign_taxes
    result = TaxCalculator.call(
      amount_cents: pfu_amount_cents.to_i + enterprise_amount_cents.to_i,
      simple: true
    )

    self.income_tax_cents = result[:income_tax_cents].to_i
    self.military_tax_cents = result[:military_tax_cents].to_i
    self.net_amount_cents = result[:net_amount_cents].to_i
  end

  def amounts_changed?
    will_save_change_to_pfu_amount_cents? || will_save_change_to_enterprise_amount_cents?
  end
end
