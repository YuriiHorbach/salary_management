# frozen_string_literal: true

# Renders departments and the employees assigned to a department.
#
# The +show+ action supports filtering by position: the employee list, salary
# column and footer total are all scoped to the selected position. Salaries for
# the selected period are grouped by employee and position so the salary cell can
# show one line per position, with a separate add link for every position that
# has no salary yet. The view links each employee to
# +DepartmentEmployeePositionsController#edit+ to manage assignments.
class DepartmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department, only: %i[edit update show]

  def index
    @departments = Department.all
  end

  def new
    @department = Department.new
  end

  def show
    @q = @department.employees.ransack(params[:q])
    @positions = @department.positions.order(:position_name)
    @position = @department.positions.find_by(id: params[:position])
    @employees = filtered_employees.to_a
    @period = selected_period
    @period_salaries = @department.salary_amounts_by_employee_and_position(
      @period,
      position: @position,
      employee_ids: @employees.map(&:id)
    )
    @employee_positions = DepartmentEmployeePositionsQuery.new(
      @department,
      employee_ids: @employees.map(&:id),
      period_salaries: @period_salaries,
      position: @position
    ).call
    @department_total = @department.monthly_total(@period, position: @position)
  end

  def edit; end

  def create
    @department = Department.new(department_params)
    if @department.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: 'Listing was successfully created.' }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @department.update(department_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: 'Department updated successfully!' }
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name)
  end

  def selected_period
    Date.strptime(params[:period].to_s, '%Y-%m').beginning_of_month
  rescue ArgumentError
    current_working_month
  end

  def filtered_employees
    employees = @q.result(distinct: true)
    return employees unless @position

    employee_ids = @department.department_employees.where(position_id: @position.id).select(:employee_id)
    employees.where(id: employee_ids)
  end
end
