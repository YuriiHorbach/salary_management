# frozen_string_literal: true

# Singleton model that keeps the configuration used by TaxCalculator.
#
# A single row holds the tax rates and thresholds. Changing this record only
# affects calculations performed afterwards; already persisted results are not
# recalculated.
class TaxSetting < ApplicationRecord
  # Default values used to seed the singleton when no configuration exists yet.
  DEFAULTS = {
    income_rate: BigDecimal('0.18'), # 18%
    military_rate: BigDecimal('0.05'), # 5%
    gran_dohid_uah: BigDecimal(4660), # граничний дохід для ПСП у грн
    psp_uah: BigDecimal(1664) # податкова соціальна пільга (звичайна)
  }.freeze

  validates :income_rate, :military_rate, :gran_dohid_uah, :psp_uah,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  # Returns the single settings row, creating it from the defaults the first
  # time it is needed.
  def self.current
    first || create!(DEFAULTS)
  end
end
