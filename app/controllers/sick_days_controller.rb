# frozen_string_literal: true

class SickDaysController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_employee
  before_action :set_sick_day, only: %i[edit update destroy]

  def index
    @sick_days = @employee.sick_days.order(period: :desc)
  end

  def new
    @sick_day = @employee.sick_days.build
  end

  def create
    @sick_day = @employee.sick_days.build(sick_day_params)

    if @sick_day.save
      redirect_to employee_sick_days_path(@employee), notice: 'Лікарняний успішно додано.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @sick_day.update(sick_day_params)
      redirect_to employee_sick_days_path(@employee), notice: 'Лікарняний успішно оновлено.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @sick_day.destroy

    redirect_to employee_sick_days_path(@employee), notice: 'Лікарняний успішно видалено.'
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_sick_day
    @sick_day = SickDay.find(params[:id])
  end

  def sick_day_params
    params.require(:sick_day).permit(:period, :pfu_amount_cents, :enterprise_amount_cents)
  end
end
