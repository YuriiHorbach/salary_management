# frozen_string_literal: true

# Singleton model that keeps the configuration used by TaxCalculator.
#
# A single row holds the tax rates and thresholds. Changing this record only
# affects calculations performed afterwards; already persisted results are not
# recalculated.
class TaxSetting < ApplicationRecord
  validates :income_rate, :military_rate, :gran_dohid_uah, :psp_uah,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  # Returns the single settings row, creating it from the TaxCalculator
  # defaults the first time it is needed.
  def self.current
    first || create!(
      income_rate: TaxCalculator::INCOME_TAX_RATE,
      military_rate: TaxCalculator::MILITARY_TAX_RATE,
      gran_dohid_uah: TaxCalculator::GRAN_DOHID_UAH,
      psp_uah: TaxCalculator::PSP_UAH
    )
  end
end
