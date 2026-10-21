# frozen_string_literal: true

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
    employees = @q.result(distinct: true)

    if params[:position].present?
      employee_ids = @department.department_employees.where(position_id: params[:position]).select(:employee_id)
      employees = employees.where(id: employee_ids)
    end

    @employees = employees.to_a
    @positions = @department.positions.order(:position_name)
    @period = selected_period
    @period_salaries = Salary.where(employee_id: @employees.map(&:id), period: @period).index_by(&:employee_id)
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
    Date.current.beginning_of_month
  end
end
