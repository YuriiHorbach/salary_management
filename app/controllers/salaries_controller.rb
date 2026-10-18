# frozen_string_literal: true

# app/controllers/salaries_controller.rb
class SalariesController < ApplicationController
  # before_action :set_department
  before_action :set_employee
  before_action :set_salary, only: %i[show edit update destroy]

  def index
    @salaries = @employee.salaries
  end

  def show; end

  def new
    @employee = Employee.find(params[:employee_id])
    @salary = @employee.salaries.new
  end

  def create
    @employee = Employee.find(params[:employee_id])
    @salary = @employee.salaries.build(salary_params)

    @salary.department_id ||= params[:department_id] || params.dig(:salary, :department_id)

    if @salary.save
      @department = Department.find(@salary.department_id)
      @department_total = @department.monthly_total

      respond_to do |format|
        format.html { redirect_to department_path(@department), notice: 'Salary added successfully.' }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @salary.update(salary_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employee_salaries_path(@employee), notice: 'Salary updated successfully.' }
      end
    else
      render :edit
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
    params.require(:salary).permit(:amount, :paid_on, :employee_id, :department_id)
  end
end
