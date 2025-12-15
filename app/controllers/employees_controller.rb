# frozen_string_literal: true

class EmployeesController < ApplicationController
  before_action :authenticate_user!
  # before_action :employee, only: %i[edit update destroy]
  before_action :set_employee, only: %i[edit update destroy]

  def index
    # @employees = Employee.all
    @q = Employee.ransack(params[:q])
    @employees = @q.result(distinct: true)
  end

  def show # rubocop:disable Metrics/AbcSize
    @employee = Employee.find_by(id: params[:id])
    @q = @employee.salaries.ransack(params[:q])
    @departments = Department.all
    @employee_salaries = @q.result.includes(:department).group_by(&:department)
    @monthly_totals = @q.result.group_by do |s|
      s.paid_on.strftime('%Y-%m')
    end.transform_values { |sals| sals.sum(&:amount) }
    # Ruby-фільтрація по місяцю/року
    if params[:month].present?
      month_param = params[:month].rjust(2, '0')
      @monthly_totals.select! { |m, _| m.split('-').last == month_param }
    end
    @monthly_totals.select! { |m, _| m.split('-').first == params[:year] } if params[:year].present?
    return unless @employee.nil?

    flash[:alert] = 'Співробітника не знайдено.'
    redirect_to employees_path
  end

  def new
    @employee = Employee.new
  end

  def create
    @employee = Employee.new(employee_params)

    if @employee.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: 'Employee created successfully!' }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @employee.update(employee_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: 'Employee updated successfully!' }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to employees_path, notice: 'Employee deleted successfully!' }
    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:id])
  end

  def employee_params
    params.require(:employee).permit(:first_name, :last_name, :patronic_name, :id_code)
  end
end
