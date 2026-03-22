# frozen_string_literal: true

class EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_employee, only: %i[edit update destroy]

  def index
    @q = Employee.ransack(params[:q])
    @employees = @q.result(distinct: true)
  end

  def show
    @employee = Employee.find_by(id: params[:id])
    return redirect_to employees_path, alert: 'Співробітника не знайдено.' if @employee.nil?

    @permitted_params = params.permit(:year, :month, :direction, :sort, q: {})

    @permitted_params = params.permit(:year, :month, :direction, :sort, q: {})

    @salary_q = @employee.salaries.ransack(params[:salary_q], search_key: :salary_q) # використовуй :salary_q з params
    @employee_salaries = @salary_q.result.includes(:department).group_by(&:department)

    @departments = Department.all

    prepare_monthly_totals(@salary_q)

    @vacation_q = @employee.vacations.ransack(params[:vacation_q], search_key: :vacation_q)
    @vacations = @vacation_q.result.order(period: :desc)

    @sick_days_summaries = @employee.addition_income_summaries(@employee.sick_days)
    @vacations_summaries = @employee.addition_income_summaries(@employee.vacations)
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
    params.require(:employee).permit(:first_name,
                                     :last_name,
                                     :patronic_name,
                                     :id_code,
                                     :territory_info,
                                     :chaes,
                                     :contract,
                                     :disability_group,
                                     :children_count)
  end

  def prepare_monthly_totals(q)
    @monthly_totals = q.result.group_by { |s| s.paid_on.strftime('%Y-%m') }
                       .transform_values { |sals| sals.sum(&:amount_cents) / 100.0 }

    if params[:month].present?
      month_param = params[:month].rjust(2, '0')
      @monthly_totals.select! { |m, _| m.split('-').last == month_param }
    end

    @monthly_totals.select! { |m, _| m.split('-').first == params[:year] } if params[:year].present?
  end
end
