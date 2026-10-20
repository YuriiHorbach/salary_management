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
    ids = selected_employee_ids

    if ids.empty?
      redirect_to @department, alert: 'No employees selected.'
      return
    end

    employee_ids = Employee.where(id: ids).pluck(:id)

    if employee_ids.empty?
      redirect_to @department, alert: 'No employees selected.'
      return
    end

    new_ids = employee_ids - @department.department_employees.where(employee_id: employee_ids).pluck(:employee_id)

    if new_ids.empty?
      redirect_to @department, alert: 'Selected employees are already in this department.'
      return
    end

    now = Time.current
    DepartmentEmployee.insert_all(
      new_ids.map do |employee_id|
        { department_id: @department.id, employee_id: employee_id, created_at: now, updated_at: now }
      end
    )

    redirect_to @department, notice: "Employees added to the department: #{new_ids.size}."
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

  def selected_employee_ids
    Array(params[:employee_ids]).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
  end

  def set_department
    @department = Department.find(params[:department_id])
  end
end
