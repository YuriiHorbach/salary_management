# frozen_string_literal: true

# Adds positions to a department's position dictionary.
#
# The per-employee positions page uses this controller to create a position
# when the department has no suitable one yet. After a successful create it
# returns to that employee's positions page and pre-selects the new position;
# when no valid employee context is given it falls back to the department page.
# The +return_period+ and +return_position+ params are used to restore the
# period and position filter of the originating department page.
class DepartmentPositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department

  def create
    @position = @department.positions.new(position_params)

    if @position.save
      redirect_to after_create_path, notice: t('flash.department_positions.created')
    else
      redirect_to after_create_path, alert: @position.errors.full_messages.to_sentence
    end
  end

  private

  def set_department
    @department = Department.find(params[:department_id])
  end

  def position_params
    params.expect(position: [:position_name])
  end

  def after_create_path
    return department_path(@department, **return_context) unless employee_in_department?

    options = { department_id: @department.id, employee_id: params[:employee_id] }
    options[:new_position_id] = @position.id if @position.persisted?
    options.merge!(return_context)

    edit_department_employee_positions_path(options)
  end

  def return_context
    {
      period: params[:return_period].presence,
      position: params[:return_position].presence
    }.compact
  end

  def employee_in_department?
    return false if params[:employee_id].blank?

    @department.department_employees.exists?(employee_id: params[:employee_id])
  end
end
