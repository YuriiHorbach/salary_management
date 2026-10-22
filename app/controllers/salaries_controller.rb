# frozen_string_literal: true

# Manages salary records for an employee, including the inline add form used on
# the department page. The inline form offers the employee's positions in the
# department, defaults to the selected filter or the only available position,
# and submits only through its explicit save button so choosing a position cannot
# send an empty amount. Successful inline creates replace the employee's whole
# salary cell, preserving one line per position.
#
# The index also exposes a gross salary breakdown grouped by department and
# position for the selected period. Taxes remain monthly aggregates and are not
# allocated per position.
class SalariesController < ApplicationController
  before_action :set_employee
  before_action :set_salary, only: %i[show edit update destroy]

  def index
    @period = requested_period if params[:period].present?
    @salaries = @employee.salaries.includes(:department, :position).order(period: :desc)
    @salaries = @salaries.where(period: @period) if @period
    @period_incomes = EmployeePeriodIncome.where(employee: @employee).order(period: :desc)
    @period_incomes = @period_incomes.for_period(@period) if @period
    @departments = @employee.departments.distinct.order(:name)
    load_salary_totals_by_position
  end

  def show; end

  def new
    @salary = @employee.salaries.new(period: requested_period,
                                     department_id: params[:department_id])
    load_positions
    @salary.position_id = default_position_id
  end

  def create
    @salary = @employee.salaries.build(salary_params)

    @salary.department_id ||= params[:department_id] || params.dig(:salary, :department_id)
    @salary.position_id ||= params[:position_id].presence

    if @salary.save
      load_inline_department_context

      respond_to do |format|
        format.html { redirect_after_create }
        format.turbo_stream
      end
    else
      load_positions
      render :new, status: :unprocessable_content
    end
  end

  def edit
    load_positions
  end

  def update
    if @salary.update(salary_params)
      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to employee_salaries_path(@employee, period: @salary.period.strftime('%Y-%m')),
                      notice: 'Salary updated successfully.'
        end
      end
    else
      load_positions
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @salary.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to employee_salaries_path(@employee), notice: 'Salary deleted successfully.' }
    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_department
    @department = Department.find(params[:department_id])
  end

  def set_salary
    @salary = @employee.salaries.find(params[:id])
  end

  def salary_params
    params.require(:salary).permit(:amount, :paid_on, :period, :employee_id, :department_id, :position_id)
  end

  def load_positions
    @positions =
      if @salary.department_id.present?
        employee_scope = { employee_id: @employee.id, department_id: @salary.department_id }
        scope = Position.joins(:department_employees)
                        .where(department_employees: employee_scope)
                        .distinct
        scope = scope.where(id: params[:position]) if params[:position].present?
        scope.order(:position_name)
      else
        Position.none
      end
  end

  def default_position_id
    requested = @positions.find_by(id: params[:position_id])
    return requested.id if requested
    return @positions.first.id if @positions.one?

    nil
  end

  def requested_period
    Date.strptime(params[:period].to_s, '%Y-%m').beginning_of_month
  rescue ArgumentError
    current_working_month
  end

  def redirect_after_create
    if @department
      options = { period: @salary.period.strftime('%Y-%m') }
      options[:position] = params[:position] if params[:position].present?
      redirect_to department_path(@department, **options), notice: 'Salary added successfully.'
    else
      redirect_to employee_salaries_path(@employee), notice: 'Salary added successfully.'
    end
  end

  # Prepares the data needed by +departments/_salary_cell+ after an inline
  # create. The salary cell is replaced as a whole because an employee may have
  # several positions and only one of their amounts changed.
  def load_inline_department_context
    @department = @salary.department
    return unless @department

    @period_salaries = @department.salary_amounts_by_employee_and_position(
      @salary.period,
      position: params[:position],
      employee_ids: [@employee.id]
    )
    @employee_salary_positions = inline_employee_positions
    @department_total = @department.monthly_total(@salary.period, position: params[:position])
  end

  def inline_employee_positions
    assignments = @department.department_employees.where(employee_id: @employee.id)
    assignments = assignments.where(position_id: params[:position]) if params[:position].present?
    positions = assignments.includes(:position).filter_map(&:position).uniq

    salary_position_ids = @period_salaries.keys.filter_map(&:last).compact
    positions |= @department.positions.where(id: salary_position_ids).to_a
    positions.sort_by(&:position_name)
  end

  def load_salary_totals_by_position
    @salary_totals_by_position = @employee.salary_totals_by_department_and_position(period: @period)

    keys = @salary_totals_by_position.keys
    @summary_departments = Department.where(id: keys.filter_map(&:first)).index_by(&:id)
    @summary_positions = Position.where(id: keys.filter_map(&:last)).index_by(&:id)
  end
end
