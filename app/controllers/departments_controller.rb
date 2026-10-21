# frozen_string_literal: true

# Renders departments and the employees assigned to a department.
#
# The +show+ action supports filtering by position, preloads salaries for the
# selected period, and exposes positions grouped by employee so the view can
# link each employee to +DepartmentEmployeePositionsController#edit+.
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
    @employees = filtered_employees.to_a
    @positions = @department.positions.order(:position_name)
    @employee_positions = positions_by_employee
    @period = selected_period
    @period_salaries = Salary.where(employee_id: @employees.map(&:id), department_id: @department.id, period: @period)
                             .group(:employee_id)
                             .sum(:amount_cents)
    @department_total = @department.monthly_total(@period)
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
    return employees if params[:position].blank?

    employee_ids = @department.department_employees.where(position_id: params[:position]).select(:employee_id)
    employees.where(id: employee_ids)
  end

  def positions_by_employee
    @department.department_employees
               .where(employee_id: @employees.map(&:id))
               .includes(:position)
               .group_by(&:employee_id)
               .transform_values { |assignments| assignments.filter_map(&:position).uniq.sort_by(&:position_name) }
  end
end
