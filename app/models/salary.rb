class Salary < ApplicationRecord
  belongs_to :employee
  belongs_to :department, optional: true

  after_save :update_employee_total_salary
  after_destroy :update_employee_total_salary
  before_validation :set_department_from_employee_departments

  def self.ransackable_attributes(*)
    %w[amount created_at department_id employee_id id paid_on updated_at]
  end

  def self.ransackable_associations(*)
    %w[department employee]
  end

  def month
    paid_on&.strftime('%Y-%m')
  end

  def year
    paid_on&.year
  end

  def self.monthly_sum_for_employee(employee_id)
    where(employee_id: employee_id).group("EXTRACT(YEAR FROM paid_on)", "EXTRACT(MONTH FROM paid_on)")
      .sum(:amount)
  end

  private

  def update_employee_total_salary
    employee.update(total_salary: employee.salaries.sum(:amount))
  end

  def set_department_from_employee_departments
    if department_id.blank? && employee && employee.departments.any?
      self.department_id = employee.departments.first.id
    end
  end
end
