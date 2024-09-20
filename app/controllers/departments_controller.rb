class DepartmentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @departments = Department.all
  end

  def show
    @department = Department.find(params[:id])
    @employees = @department.employees.includes(:department_employees, :salaries).distinct
  end
end
