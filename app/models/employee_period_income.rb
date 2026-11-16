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

  belongs_to :employee

  enum :income_type, { salary: 'salary', vacation: 'vacation', sick_day: 'sick_day' }, validate: true

  validates :period, presence: true
  validates :employee_id, uniqueness: { scope: %i[period income_type] }
  validates :tax_benefit, inclusion: { in: TAX_BENEFITS }, allow_nil: true

  scope :for_period, ->(period) { where(period: period) }
end
