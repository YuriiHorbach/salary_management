# frozen_string_literal: true

class VacationsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_employee
  before_action :set_vacation, only: %i[edit update destroy]

  def index
    @q = @employee.vacations.ransack(params[:q])

    @vacations = @q.result(distinct: true).order(period: :desc)

    @total_vacation_amount = @q.result.distinct(false).unscope(:order).sum(:vacation_amount_cents)
  end

  def new
    @vacation = @employee.vacations.build
  end

  def create
    @vacation = @employee.vacations.build(vacation_params)

    if @vacation.save
      redirect_to employee_vacations_path(@employee), notice: 'Відпустку успішно додано.'
    else
      puts @vacation.errors.full_messages
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vacation.update(vacation_params)
      redirect_to employee_vacations_path(@employee), notice: 'Відпустку успішно оновлено.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vacation.destroy

    redirect_to employee_vacations_path(@employee), notice: 'Відпустку успішно видалено.',
                                                    turb_stream: turbo_stream.remove(@vacation)
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_vacation
    @vacation = Vacation.find(params[:id])
  end

  def vacation_params
    # params.require(:vacation).permit(:period, :vacation_amount_cents)
    params.require(:vacation).permit(:period, :vacation_amount)
  end
end
