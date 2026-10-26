# frozen_string_literal: true

# Renders departments and the employees assigned to a department.
#
# The +show+ action supports filtering by position: the employee list, salary
# column and footer total are all scoped to the selected position. Salaries for
# the selected period are grouped by employee and position so the salary cell can
# show one line per position, with a separate add link for every position that
# has no salary yet. The view links each employee to
# +DepartmentEmployeePositionsController#edit+ to manage assignments.
# Employees are ordered by last name ascending unless the user requests another
# sort. Standard columns use Ransack; position and salary use
# +DepartmentEmployeeSortQuery+ because their values depend on the selected
# period and position filter.
class DepartmentsController < ApplicationController
  DEFAULT_EMPLOYEE_SORT = 'last_name asc'

  before_action :authenticate_user!
  before_action :set_department, only: %i[edit update show destroy]

  def index
    @departments = Department.all
    @employee_counts = Department.employee_counts
  end

  def new
    @department = Department.new
  end

  def show
    @q = employee_search
    @employees_count = @department.department_employees.distinct.count(:employee_id)
    @positions = @department.positions.order(:position_name).to_a
    @position = @positions.find { |position| position.id.to_s == params[:position].to_s } if params[:position].present?
    @period = selected_period
    employees = filtered_employees.to_a
    load_employee_salary_context(employees)
    @employees = sort_employees(employees)
    @department_total = @department.monthly_total(@period, position: @position)
  end

  def edit; end

  def create
    @department = Department.new(department_params)
    if @department.save
      @employee_counts = Department.employee_counts
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: t('flash.departments.created') }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @department.update(department_params)
      @employee_counts = Department.employee_counts
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: t('flash.departments.updated') }
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Deletes a department and removes its card via Turbo Stream or redirects to departments_path.
  def destroy
    @department.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@department) }
      format.html { redirect_to departments_path, notice: t('flash.departments.deleted') }
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def load_employee_salary_context(employees)
    employee_ids = employees.map(&:id)
    @period_salaries = @department.salary_amounts_by_employee_and_position(
      @period,
      position: @position,
      employee_ids: employee_ids
    )
    @employee_positions = DepartmentEmployeePositionsQuery.new(
      @department,
      employee_ids: employee_ids,
      period_salaries: @period_salaries,
      position: @position
    ).call
  end

  # Builds the Ransack search and applies the default order when the request
  # does not specify one. Custom position/salary sorts are removed before
  # Ransack sees them and applied later by +DepartmentEmployeeSortQuery+.
  #
  # @return [Ransack::Search] employee search for the department
  def employee_search
    search = @department.employees.ransack(ransack_search_params)
    search.sorts = [DEFAULT_EMPLOYEE_SORT] if search.sorts.empty? && !custom_sort?
    search
  end

  def ransack_search_params
    return {} if params[:q].blank?

    permitted = params[:q].permit(:s).to_h
    permitted.delete('s') if custom_sort?
    permitted
  end

  def custom_sort?
    DepartmentEmployeeSortQuery.custom_sort?(params.dig(:q, :s))
  end

  # Applies position or salary ordering after the displayed positions and
  # period salaries have been loaded. Standard Ransack sorts pass through
  # unchanged.
  def sort_employees(employees)
    DepartmentEmployeeSortQuery.new(
      employees,
      sort: params.dig(:q, :s),
      positions_by_employee: @employee_positions,
      salary_totals: employee_salary_totals
    ).call
  end

  def employee_salary_totals
    @period_salaries.each_with_object(Hash.new(0)) do |((employee_id, _position_id), amount), totals|
      totals[employee_id] += amount
    end
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
