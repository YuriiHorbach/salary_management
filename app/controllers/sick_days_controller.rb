class SickDaysController < ApplicationController
  before_action :set_employee, only: [:index, :new, :create]

  def index 
    @sick_days = @employee.sick_days.order(period: :desc)
  end

  def new 
    @sick_day = @employee.sick_days.build
  end

  def create 
    @sick_day = @employee.sick_days.build(sick_day_params)

    if params[:sick_day][:period].present?
      @sick_day.period = Date.parse("#{params[:sick_day][:period]}-01")
    end

    if @sick_day.save 
      redirect_to new_employee_sick_day_path(@employee), notice: 'Лікарняний успішно додано. Ви можете додати ще один.'
    else 
      render :new, status: :unprocessable_entity
    end
  end

  private 

  def set_employee 
    @employee = Employee.find(params[:employee_id])
  end

  def sick_day_params 
    params.require(:sick_day).permit(:period, :pfu_amount, :enterprise_amount)
  end
end