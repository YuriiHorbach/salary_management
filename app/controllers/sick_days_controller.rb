class SickDaysController < ApplicationController
  before_action :set_employee, only:[:index, :new, :create]

  def index 
    @sick_days = @employee.sick_days
  end

  def new 
    @sick_day = SickDay.new(params[:employee_id])
  end

  def create 
    @sick_day = @employee.sick_days.build(sick_day_params)

    if @sick_day.save 
      redirect_to :root 
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
