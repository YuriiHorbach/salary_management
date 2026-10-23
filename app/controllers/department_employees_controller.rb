# frozen_string_literal: true

# app/controllers/department_employees_controller.rb
class DepartmentEmployeesController < ApplicationController
  SEARCH_KEYS = %i[id_code_cont last_name_cont first_name_cont patronic_name_cont s].freeze

  before_action :authenticate_user!
  before_action :set_department, only: %i[new create]

  def new
    @q = Employee.ransack(employee_search_params)
    @employees = @q.result(distinct: true)
    @positions = @department.positions.order(:position_name)
  end

  def create
    ids = selected_employee_ids
    return redirect_with_alert('No employees selected.') if ids.empty?

    employee_ids = Employee.where(id: ids).pluck(:id)
    return redirect_with_alert('No employees selected.') if employee_ids.empty?

    position = selected_position

    if params[:position_id].present? && position.nil?
      return redirect_with_alert('Посаду не знайдено в цьому підрозділі.')
    end

    new_ids = employee_ids.reject { |employee_id| assignment_exists?(employee_id, position) }
    return redirect_with_alert(duplicate_message(position)) if new_ids.empty?

    insert_assignments(new_ids, position)

    redirect_to @department, notice: "Employees added to the department: #{new_ids.size}."
  end

  def destroy
    assignments = DepartmentEmployee.where(department_id: params[:department_id], employee_id: params[:id])

    if assignments.exists?
      assignments.delete_all
      flash[:notice] = 'Employee was successfully removed from the department.'
    else
      flash[:alert] = 'Employee not found in the department.'
    end

    redirect_to department_path(params[:department_id])
  end

  private

  def employee_search_params
    return {} if params[:q].blank?

    params[:q].permit(*SEARCH_KEYS).to_h.tap do |search|
      search['id_code_cont'] = search['id_code_cont'].to_s.strip.upcase if search['id_code_cont'].present?
    end
  end

  def selected_employee_ids
    Array(params[:employee_ids]).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
  end

  def selected_position
    return if params[:position_id].blank?

    @department.positions.find_by(id: params[:position_id])
  end

  def assignment_exists?(employee_id, position)
    assignments = @department.department_employees.where(employee_id: employee_id)

    position ? assignments.exists?(position_id: position.id) : assignments.exists?
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
      'Selected employees already have this position in the department.'
    else
      'Selected employees are already in this department.'
    end
  end

  def redirect_with_alert(message)
    redirect_to @department, alert: message
  end

  def set_department
    @department = Department.find(params[:department_id])
  end
end
