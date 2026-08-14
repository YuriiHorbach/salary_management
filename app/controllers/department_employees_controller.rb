# frozen_string_literal: true

# app/controllers/department_employees_controller.rb
class DepartmentEmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department, only: %i[new create]

  def new
    @q = Employee.ransack(params[:q])
    @employees = @q.result(distinct: true)
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

    redirect_to @department
  end

  def destroy
    department_employee = DepartmentEmployee.find_by(department_id: params[:department_id], employee_id: params[:id])

    if department_employee
      department_employee.destroy
      flash[:notice] = 'Employee was successfully removed from the department.'
    else
      flash[:alert] = 'Employee not found in the department.'
    end

    redirect_to department_path(params[:department_id])
  end

  private

  def department_employee_params
    params.require(:department_employee).permit(employee_ids: [])
  end

  def set_department
    @department = Department.find(params[:department_id])
  end
end
