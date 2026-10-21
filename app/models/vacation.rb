# Vacation payment for an employee.
#
# Per-record taxes are kept for display, while +Incomes::PeriodRecalculator+
# calculates the authoritative taxes on the total vacation amount of a month.
class Vacation < ApplicationRecord
  belongs_to :employee

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
