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
    @employees = filtered_employees.to_a
    @positions = @department.positions.order(:position_name)
    @position = @department.positions.find_by(id: params[:position])
    @period = selected_period
    @period_salaries = @department.salary_amounts_by_employee_and_position(
      @period,
      position: params[:position],
      employee_ids: @employees.map(&:id)
    )
    @employee_positions = positions_by_employee
    @department_total = @department.monthly_total(@period, position: params[:position])
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
    grouped = assigned_positions_by_employee
    merge_salary_positions!(grouped)
    grouped.transform_values { |positions| positions.sort_by(&:position_name) }
  end

  def assigned_positions_by_employee
    assignments = @department.department_employees.where(employee_id: @employees.map(&:id))
    assignments = assignments.where(position_id: @position.id) if @position
    assignments.includes(:position)
               .group_by(&:employee_id)
               .transform_values { |rows| rows.filter_map(&:position).uniq }
  end

  def merge_salary_positions!(grouped)
    salary_positions = @department.positions
                                  .where(id: @period_salaries.keys.filter_map(&:last).compact.uniq)
                                  .index_by(&:id)

    @period_salaries.each_key do |employee_id, position_id|
      next if position_id.blank?

      position = salary_positions[position_id]
      next unless position

      employee_positions = grouped[employee_id] ||= []
      employee_positions << position unless employee_positions.any? { |existing| existing.id == position.id }
    end
  end
end
