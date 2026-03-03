# frozen_string_literal: true

class SickDaysController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_employee, only: %i[index new create edit update destroy]
  def index
    @sick_days = @employee.sick_days.order(period: :desc)

    @sick_days_summaries = @employee.sick_days_summaries
  end

  def new
    @sick_day = @employee.sick_days.build
  end

  def create
    @sick_day = @employee.sick_days.build(sick_day_params)

    @sick_day.period = Date.parse("#{params[:sick_day][:period]}-01") if params[:sick_day][:period].present?

    if @sick_day.save
      redirect_to new_employee_sick_day_path(@employee), notice: 'Лікарняний успішно додано. Ви можете додати ще один.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @sick_day = @employee.sick_days.find(params[:id])
  end

  def update
    @sick_day = @employee.sick_days.find(params[:id])
    @sick_day.period = Date.parse("#{params[:sick_day][:period]}-01") if params[:sick_day][:period].present?

    if @sick_day.update(sick_day_params.except(:period))
      @sick_days_summaries = @employee.sick_days_summaries

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(dom_id(@sick_day), partial: 'sick_days/row', locals: { sd: @sick_day }),

            turbo_stream.replace("summary_#{@sick_day.period.strftime('%Y-%m')}",
                                 partial: 'sick_days/summary_row',
                                 locals: { period: @sick_day.period, summaries: @sick_days_summaries })
          ]
        end
        format.html { redirect_to employee_sick_days_path(@employee), notice: 'Оновлено!' }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sick_day = @employee.sick_days.find(params[:id])
    @sick_day.destroy

    @sick_days_summaries = @employee.sick_days_summaries

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(@sick_day)),

          turbo_stream.replace("summary_#{@sick_day.period.strftime('%Y-%m')}",
                               partial: 'sick_days/summary_row',
                               locals: { period: @sick_day.period, summaries: @sick_days_summaries })
        ]
      end
      format.html { redirect_to employee_sick_days_path(@employee), notice: 'Видалено' }
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
