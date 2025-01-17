# app/controllers/department_employees_controller.rb
class DepartmentEmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department, only: %i[new create]

  def new
    @employees = Employee.all
  end

  def create
    employee_ids = params[:employee_ids]

    if employee_ids&.any?
      employees = Employee.where(id: employee_ids)
      employees.each do |employee|
        @department.employees << employee unless @department.employees.exists?(id: employee.id)
      end
      flash[:notice] = 'Employees were successfully added to the department.'
    else
      flash[:alert] = 'No employees selected.'
    end

    redirect_to @department # Redirect back to the department's show page
  end

  private

  def set_department
    @department = Department.find(params[:department_id])
  end
end
