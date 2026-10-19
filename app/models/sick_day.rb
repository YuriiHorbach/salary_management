# frozen_string_literal: true

class SickDay < ApplicationRecord
  belongs_to :employee

  attribute :period, :date

  before_validation :assign_taxes, if: :amounts_changed?

  monetize :pfu_amount_cents
  monetize :enterprise_amount_cents
  monetize :income_tax_cents
  monetize :military_tax_cents
  monetize :net_amount_cents

  validates :period, presence: true
  validates :pfu_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :enterprise_amount, numericality: { greater_than_or_equal_to: 0 }

  def total_amount
    pfu_amount + enterprise_amount
  end

  def pdfo_amount
    Money.new(income_tax_cents || 0, pfu_amount.currency)
  end

  def military_amount
    Money.new(military_tax_cents || 0, pfu_amount.currency)
  end

  private

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
