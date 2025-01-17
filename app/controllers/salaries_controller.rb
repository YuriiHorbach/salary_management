# app/controllers/salaries_controller.rb
class SalariesController < ApplicationController
  # before_action :set_department
  before_action :set_employee
  before_action :set_salary, only: %i[show edit update destroy]

  def index
    @salary_records = @employee.salaries
  end

  def show
  end

  def new
    @salary_record = @employee.salaries.new
  end

  def create
    @salary_record = @employee.salaries.new(salary_params)
    if @salary_record.save
      redirect_to employee_salaries_path(@employee), notice: 'Salary record created successfully.'
    else
      render :new
    end
  end

  def edit; end

  def update
    if @salary_record.update(salary_params)
      redirect_to employee_salaries_path(@employee), notice: 'Salary record updated successfully.'
    else
      render :edit
    end
  end

  def destroy
    @salary_record.destroy
    redirect_to employee_salaries_path(@employee), notice: 'Salary record deleted successfully.'
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_department
    @department = Department.find(params[:department_id])
  end

  def set_salary
    @salary_record = @employee.salaries.find(params[:id])
  end

  def salary_params
    params.require(:salary).permit(:amount, :paid_on, :employee_id, :department_id)
  end
end
