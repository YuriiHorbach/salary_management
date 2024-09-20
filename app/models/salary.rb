class Salary < ApplicationRecord
  belongs_to :employee
  belongs_to :position

  after_save :update_employee_total_salary
  after_destroy :update_employee_total_salary

  private

  def update_employee_total_salary
    employee.update(total_salary: employee.salaries.sum(:amount))
  end
end
