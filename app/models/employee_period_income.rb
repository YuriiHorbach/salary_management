# frozen_string_literal: true

# Stores the aggregated gross amount and the taxes calculated once per income
# type for one employee and one month.
#
# A row is the source of truth for reports: +salary+, +vacation+ and +sick_day+
# amounts are summed separately, the total gross of each type is passed through
# +TaxCalculator+, and the result is persisted here. Recalculation is handled by
# +Incomes::PeriodRecalculator+. The applied tax benefit is stored in
# +tax_benefit+ as a historical snapshot so later profile changes do not rewrite
# past reports.
class EmployeePeriodIncome < ApplicationRecord
  INCOME_TYPES = %w[salary vacation sick_day].freeze

  # Tax benefits recognised by +TaxCalculator+. Stored as a snapshot so past
  # periods keep the benefit that was actually applied.
  TAX_BENEFITS = %w[base disability ubd children single_parent disabled_children].freeze

  # Report filter codes (OZN_PILG) grouped by the stored benefit snapshots that
  # the detailed report renders under the same code.
  TAX_BENEFIT_KINDS_BY_CODE = {
    '01' => %w[base].freeze,
    '02' => %w[disability single_parent disabled_children].freeze,
    '03' => %w[ubd].freeze,
    '04' => %w[children].freeze
  }.freeze

  # Filter value that selects employees without an applied benefit.
  NO_BENEFIT = 'none'

  belongs_to :employee

  enum :income_type, { salary: 'salary', vacation: 'vacation', sick_day: 'sick_day' }, validate: true

  validates :period, presence: true
  validates :employee_id, uniqueness: { scope: %i[period income_type] }
  validates :tax_benefit, inclusion: { in: TAX_BENEFITS }, allow_nil: true

  scope :for_period, ->(period) { where(period: period) }

  # Salary rows carry the applied benefit snapshot; vacation and sick-day
  # aggregates always use the flat tax calculation without a benefit.
  scope :salary_for_period, ->(period) { for_period(period).salary }
end
