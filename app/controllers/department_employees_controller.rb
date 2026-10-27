# frozen_string_literal: true

# app/controllers/department_employees_controller.rb
class DepartmentEmployeesController < ApplicationController
  SEARCH_KEYS = %i[id_code_cont last_name_cont first_name_cont patronic_name_cont s].freeze
  DEFAULT_SORT = 'last_name asc'
  EMPLOYEES_PER_PAGE = 50

  # Adding employees is a bulk workflow, so the page shows the whole matching
  # list by default. Above this cap the user is asked to narrow the search.
  MAX_UNPAGINATED_EMPLOYEES = 700

  before_action :authenticate_user!
  before_action :set_department, only: %i[new create]

  def new
    @q = Employee.ransack(employee_search_params)
    @pagination_enabled = params[:paginate] == '1'
    load_employees(@q.result(distinct: true))
    @positions = @department.positions.order(:position_name)
  end

  def create
    ids = selected_employee_ids
    return redirect_with_alert(t('flash.department_employees.no_selection')) if ids.empty?

    employee_ids = Employee.where(id: ids).pluck(:id)
    return redirect_with_alert(t('flash.department_employees.no_selection')) if employee_ids.empty?

    position = selected_position

    if params[:position_id].present? && position.nil?
      return redirect_with_alert(t('flash.department_employee_positions.not_found'))
    end

    existing_ids = existing_assignment_employee_ids(employee_ids, position)
    new_ids = employee_ids - existing_ids
    return redirect_with_alert(duplicate_message(position)) if new_ids.empty?

    insert_assignments(new_ids, position)

    redirect_to @department, notice: t('flash.department_employees.added', count: new_ids.size)
  end

  def destroy
    assignments = DepartmentEmployee.where(department_id: params[:department_id], employee_id: params[:id])

    if assignments.exists?
      assignments.delete_all
      flash[:notice] = t('flash.department_employees.removed')
    else
      flash[:alert] = t('flash.department_employees.not_found')
    end

    redirect_to department_path(params[:department_id])
  end

  private

  # Loads the add-page list either fully (default, capped) or paginated.
  #
  # @param scope [ActiveRecord::Relation<Employee>] filtered and sorted employees
  # @return [void]
  def load_employees(scope)
    if @pagination_enabled
      @pagy, @employees = pagy(:offset, scope, limit: EMPLOYEES_PER_PAGE)
      @employees_truncated = false
      return
    end

    records = scope.limit(MAX_UNPAGINATED_EMPLOYEES + 1).to_a
    @employees_truncated = records.size > MAX_UNPAGINATED_EMPLOYEES
    @employees = records.first(MAX_UNPAGINATED_EMPLOYEES)
    @pagy = nil
  end

  def employee_search_params
    search = params[:q].present? ? params[:q].permit(*SEARCH_KEYS).to_h : {}
    search['s'] = DEFAULT_SORT if search['s'].blank?

    search['id_code_cont'] = search['id_code_cont'].to_s.strip.upcase if search['id_code_cont'].present?

    search
  end

  def selected_employee_ids
    Array(params[:employee_ids]).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
  end

  def selected_position
    return if params[:position_id].blank?

    @department.positions.find_by(id: params[:position_id])
  end

  def existing_assignment_employee_ids(employee_ids, position)
    assignments = @department.department_employees.where(employee_id: employee_ids)
    assignments = assignments.where(position_id: position.id) if position

    assignments.pluck(:employee_id)
  end

  # rubocop:disable Rails/SkipsModelValidations
  def insert_assignments(employee_ids, position)
    now = Time.current
    DepartmentEmployee.insert_all(
      employee_ids.map do |employee_id|
        {
          department_id: @department.id,
          employee_id: employee_id,
          position_id: position&.id,
          created_at: now,
          updated_at: now
        }
      end
    )
  end
  # rubocop:enable Rails/SkipsModelValidations

  def duplicate_message(position)
    if position
      t('flash.department_employees.duplicate_position')
    else
      t('flash.department_employees.duplicate_department')
    end
  end

  def redirect_with_alert(message)
    redirect_to @department, alert: message
  end

  def set_department
    @department = Department.find(params[:department_id])
  end
end
