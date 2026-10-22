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

  # Salary amounts for the given month grouped by employee and position.
  # Keys are +[employee_id, position_id]+; +position_id+ is +nil+ for salaries
  # without a position. Pass +employee_ids+ to restrict the result to the rows
  # currently rendered on the department page.
  #
  # @param date [Date, String] any date inside the target month
  # @param position [Position, Integer, nil] optional position filter
  # @param employee_ids [Array<Integer>, nil] optional employee restriction
  # @return [Hash{Array(Integer, Integer, nil) => Integer}] amounts in cents
  def salary_amounts_by_employee_and_position(date = Date.current, position: nil, employee_ids: nil)
    scope = period_salaries(date, position: position)
    scope = scope.where(employee_id: employee_ids) if employee_ids
    scope.group(:employee_id, :position_id).sum(:amount_cents)
  end
end
