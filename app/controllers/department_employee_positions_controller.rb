# frozen_string_literal: true

# Manages the positions of one employee inside one department.
#
# The department page links to +edit+, where all positions of that department
# are rendered as checkboxes. +update+ delegates the synchronization to
# +DepartmentEmployees::PositionSync+, which validates that every submitted
# position belongs to the current department and keeps the department
# membership intact when all positions are cleared.
class DepartmentEmployeePositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department
  before_action :set_employee
  before_action :ensure_membership

  def edit
    @positions = @department.positions.order(:position_name)
    @selected_position_ids = current_position_ids
    preselect_new_position
  end

  def update
    if DepartmentEmployees::PositionSync.call(
      department: @department,
      employee: @employee,
      position_ids: selected_position_ids
    )
      redirect_to @department, notice: 'Посади працівника успішно оновлено.'
    else
      redirect_to @department, alert: 'Посаду не знайдено в цьому підрозділі.'
    end
  end

  private

  def set_department
    @department = Department.find(params[:department_id])
  end

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def ensure_membership
    return if @department.department_employees.exists?(employee_id: @employee.id)

    head :not_found
  end

  def current_position_ids
    @department.department_employees.where(employee_id: @employee.id).where.not(position_id: nil).pluck(:position_id)
  end

  def preselect_new_position
    new_position_id = Integer(params[:new_position_id].to_s, exception: false)
    @selected_position_ids |= [new_position_id] if new_position_id
  end

  def selected_position_ids
    Array(params[:position_ids]).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
  end
end
