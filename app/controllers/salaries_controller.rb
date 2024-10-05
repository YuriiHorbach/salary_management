# app/controllers/salaries_controller.rb
class SalariesController < ApplicationController
  before_action :set_department
  before_action :set_salary, only: %i[edit update]

  def index
    @employees = Employee.includes(:departments, :positions, :salaries)
    @department = Department.find(params[:department_id])
    @employees_by_department = @department.employees.includes(:positions, salaries: :position).distinct

    @employee_position_salaries = @employees_by_department.map do |employee|
      employee_data = {
        employee:,
        positions: employee.positions.map do |position|
          salary = employee.salaries.find { |s| s.position_id == position.id }
          {
            position:,
            salary: salary&.amount || 'Немає даних'
          }
        end
      }
      employee_data
    end
  end

  def update
    if @salary.update(salary_params)
      respond_to do |format|
        format.html { redirect_to department_salaries_path(@department) }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "#{dom_id(@salary.employee)}_#{dom_id(@salary.position)}_salary",
            partial: 'salaries/salary_amount',
            locals: { salary: @salary }
          )
        end
      end
    else
      render :edit
    end
  end

  private

  def set_department
    @department = Department.find(params[:department_id])
  end

  def set_salary
    @salary = Salary.find(params[:id])
  end

  def salary_params
    params.require(:salary).permit(:amount, :employee_id, :position_id, :department_id)
  end
end
