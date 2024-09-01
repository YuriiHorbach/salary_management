class EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :employee, only: %i[edit update destroy]

  def index
    @employees = Employee.all
  end

  def show
    @employee = Employee.find_by(id: params[:id])
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
      redirect_to employees_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @employee.update(employee_params)
      redirect_to employees_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @employee.destroy
    redirect_to employees_path, status: :see_other
  end

  private

  def employee
    @employee = Employee.find(params[:id])
  end

  def employee_params
    params.require(:employee).permit(:first_name, :last_name, :patronic_name, :id_code)
  end
end
