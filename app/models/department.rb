# frozen_string_literal: true

# A company department. Owns positions and the employees assigned through
# +DepartmentEmployee+, and aggregates salary records for the department page.
class Department < ApplicationRecord
  has_many :department_employees
  has_many :employees, -> { distinct }, through: :department_employees
  has_many :positions, dependent: :destroy
  has_many :salaries
  has_many :sick_days
  has_many :vacations

  def self.ransackable_attributes(*)
    %w[id name created_at updated_at]
  end

  # Returns salary records for the given month. When +position+ is present,
  # only salaries linked to that position (or position id) are returned.
  def period_salaries(date = Date.current, position: nil)
    scope = salaries.where(period: date.to_date.beginning_of_month)
    return scope if position.blank?

    scope.where(position_id: position.respond_to?(:id) ? position.id : position)
  end

  # Gross salary total for the month, optionally limited to one position.
  def monthly_total(date = Date.current, position: nil)
    period_salaries(date, position: position).sum(:amount_cents) / 100.0
  end
end
