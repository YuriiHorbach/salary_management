class DepartmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department, only: %i[show update_salary]

  def index
    @departments = Department.all
  end

  def show
    @department = Department.find(params[:id])
  end

  def update_salary
    employee = Employee.find(params[:employee_id])
    position = Position.find(params[:position_id])
    department_id = Employee.find(params[:employee_id]).departments.first

    salary = Salary.find_or_initialize_by(employee:, position:)

    if salary.update(amount: params[:amount], department_id:)
      redirect_to department_path(@department), notice: 'Salary updated successfully.'
    else
      redirect_to department_path(@department), alert: 'Failed to update salary.'
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end
end
