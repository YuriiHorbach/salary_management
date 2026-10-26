# frozen_string_literal: true

# Sick leave payment split between the social fund and the employer.
#
# Per-record taxes are kept for display, while +Incomes::PeriodRecalculator+
# calculates the authoritative taxes on the total sick-day amount of a month.
class SickDay < ApplicationRecord
  belongs_to :employee
  belongs_to :department, optional: true

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
    set_pfu_amount(value.presence || 0)
  end

  def enterprise_amount=(value)
    set_enterprise_amount(value.presence || 0)
  end

  validates :period, presence: true
  validates :pfu_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :enterprise_amount, numericality: { greater_than_or_equal_to: 0 }

  def total_amount
    pfu_amount + enterprise_amount
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
