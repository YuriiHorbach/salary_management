# frozen_string_literal: true

# Manages the positions of one employee inside one department.
#
# The department page only links to +edit+. That page lists the positions the
# employee already has (each with its own edit and delete link) and renders all
# positions of the department as checkboxes. +update+ delegates the
# synchronization to +DepartmentEmployees::PositionSync+, which validates that
# every submitted position belongs to the current department and keeps the
# department membership intact when all positions are cleared. +destroy+ removes
# one position assignment through +DepartmentEmployees::PositionRemoval+, which
# also keeps the membership when the removed position was the last one.
# The +period+ and +position+ filter params from the department page are carried
# through the forms and redirects so the user returns to the same view.
class DepartmentEmployeePositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department
  before_action :set_employee
  before_action :set_context
  before_action :ensure_membership

  def edit
    @positions = @department.positions.order(:position_name)
    assigned_ids = current_position_ids
    @selected_position_ids = assigned_ids.dup
    @assigned_positions = @positions.where(id: assigned_ids)
    @highlighted_position_id = Integer(params[:position_id].to_s, exception: false)
    preselect_new_position
  end

  def update
    if DepartmentEmployees::PositionSync.call(
      department: @department,
      employee: @employee,
      position_ids: selected_position_ids
    )
      redirect_to department_path(@department, **@context_params),
                  notice: t('flash.department_employee_positions.updated')
    else
      redirect_to department_path(@department, **@context_params),
                  alert: t('flash.department_employee_positions.not_found')
    end
  end

  def destroy
    position = @department.positions.find_by(id: params[:position_id])

    if DepartmentEmployees::PositionRemoval.call(
      department: @department,
      employee: @employee,
      position: position
    )
      redirect_to edit_positions_path, notice: t('flash.department_employee_positions.deleted')
    else
      redirect_to edit_positions_path, alert: t('flash.department_employee_positions.not_found')
    end
  end

  private

  def edit_positions_path
    edit_department_employee_positions_path(department_id: @department.id, employee_id: @employee.id,
                                            **@context_params)
  end

  def set_department
    @department = Department.find(params[:department_id])
  end

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_context
    @context_params = {
      period: params[:period].presence,
      position: params[:position].presence
    }.compact
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
