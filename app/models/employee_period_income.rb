# frozen_string_literal: true

# Stores the aggregated gross amount and the taxes calculated once per income
# type for one employee and one month.
#
# A row is the source of truth for reports: +salary+, +vacation+ and +sick_day+
# amounts are summed separately, the total gross of each type is passed through
# +TaxCalculator+, and the result is persisted here. Recalculation is handled by
# +Incomes::PeriodRecalculator+.
class EmployeePeriodIncome < ApplicationRecord
  INCOME_TYPES = %w[salary vacation sick_day].freeze

  belongs_to :employee

  enum :income_type, { salary: 'salary', vacation: 'vacation', sick_day: 'sick_day' }, validate: true

  validates :period, presence: true
  validates :employee_id, uniqueness: { scope: %i[period income_type] }

  scope :for_period, ->(period) { where(period: period) }
end
