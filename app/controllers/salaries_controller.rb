# frozen_string_literal: true

# Manages salary records for an employee, including the inline add form used on
# the department page. The inline form offers the employee's positions in the
# department, defaults to the selected filter or the only available position,
# and saves when focus leaves the inline form. The form-level focusout keeps
# position selection from submitting early, while the explicit save button and
# browser validation remain available. Successful inline creates replace the
# employee's whole salary cell, preserving one line per position.
#
# The index also exposes a gross salary breakdown grouped by department and
# position for the selected period. Taxes remain monthly aggregates and are not
# allocated per position.
class SalariesController < ApplicationController
  SALARIES_PER_PAGE = 15

  before_action :authenticate_user!
  before_action :set_employee
  before_action :set_salary, only: %i[show edit update destroy]

  def index
    @period = requested_period if params[:period].present?
    salaries = @employee.salaries.includes(:department, :position).order(period: :desc)
    salaries = salaries.where(period: @period) if @period
    @pagy, @salaries = pagy(:offset, salaries, limit: SALARIES_PER_PAGE)
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
    @filter_position_id = params[:position].presence
  end

  def create
    @salary = @employee.salaries.build(salary_params)

    @salary.department_id ||= params[:department_id] || params.dig(:salary, :department_id)

    if @salary.save
      load_inline_department_context

      respond_to do |format|
        format.html { redirect_after_create }
        format.turbo_stream
      end
    else
      load_positions
      @filter_position_id = params[:position].presence
      render_validation_error(:new)
    end
  end

  def edit
    load_positions
  end

  def update
    if @salary.update(salary_params)
      load_salary_totals_for_response

      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to employee_salaries_path(@employee, period: @salary.period.strftime('%Y-%m')),
                      notice: t('flash.salaries.updated')
        end
      end
    else
      load_positions
      render_validation_error(:edit)
    end
  end

  def destroy
    @salary.destroy
    load_salary_totals_for_response

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to employee_salaries_path(@employee), notice: t('flash.salaries.deleted') }
    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_salary
    @salary = @employee.salaries.find(params[:id])
  end

  def salary_params
    params.require(:salary).permit(:amount, :paid_on, :period, :department_id, :position_id)
  end

  def load_positions
    employee_scope = { employee_id: @employee.id }
    employee_scope[:department_id] = @salary.department_id if @salary.department_id.present?

    scope = Position.joins(:department_employees)
                    .where(department_employees: employee_scope)
                    .distinct
    scope = scope.where(id: params[:position]) if params[:position].present?
    @positions = scope.order(:position_name)
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
      options[:position] = effective_filter_position if effective_filter_position.present?
      redirect_to department_path(@department, **options), notice: t('flash.salaries.created')
    else
      redirect_to employee_salaries_path(@employee), notice: t('flash.salaries.created')
    end
  end

  # Renders validation errors for both regular HTML requests and Turbo requests.
  # The inline create form lives inside +salary_cell_employee_<id>+, while the
  # edit form lives inside +salary_<id>+, so each failure replaces its own turbo
  # frame instead of trying to render a full page inside it.
  def render_validation_error(template)
    respond_to do |format|
      format.html { render template, status: :unprocessable_content }
      format.turbo_stream do
        if template == :new
          render turbo_stream: turbo_stream.replace(
            "salary_cell_employee_#{@employee.id}",
            partial: 'salaries/inline_form',
            locals: {
              employee: @employee,
              salary: @salary,
              positions: @positions,
              filter_position_id: @filter_position_id
            }
          ), status: :unprocessable_content
        else
          render :edit, status: :unprocessable_content
        end
      end
    end
  end

  def effective_filter_position
    @salary.position_id.present? ? params[:position].presence : nil
  end

  # Prepares the data needed by +departments/_salary_cell+ after an inline
  # create. The salary cell is replaced as a whole because an employee may have
  # several positions and only one of their amounts changed.
  def load_inline_department_context
    @department = @salary.department
    return unless @department

    @filter_position_id = effective_filter_position
    @period_salaries = @department.salary_amounts_by_employee_and_position(
      @salary.period,
      position: @filter_position_id,
      employee_ids: [@employee.id]
    )
    @employee_salary_positions = inline_employee_positions
    @department_total = @department.monthly_total(@salary.period, position: @filter_position_id)
  end

  def inline_employee_positions
    DepartmentEmployeePositionsQuery.new(
      @department,
      employee_ids: [@employee.id],
      period_salaries: @period_salaries,
      position: @filter_position_id
    ).call.fetch(@employee.id, [])
  end

  # Reloads the gross position summary after an update or deletion so the turbo
  # stream can replace the table without waiting for a full page reload.
  def load_salary_totals_for_response
    @period = requested_period if params[:period].present?
    load_salary_totals_by_position
  end

  def load_salary_totals_by_position
    @salary_totals_by_position = @employee.salary_totals_by_department_and_position(period: @period)

    keys = @salary_totals_by_position.keys
    @summary_departments = Department.where(id: keys.filter_map(&:first)).index_by(&:id)
    @summary_positions = Position.where(id: keys.filter_map(&:last)).index_by(&:id)
    @salary_totals_by_position = @salary_totals_by_position.sort_by do |(department_id, position_id), _|
      [
        @summary_departments[department_id]&.name.to_s,
        @summary_positions[position_id]&.position_name.to_s
      ]
    end.to_h
  end
end
