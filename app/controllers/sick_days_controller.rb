# frozen_string_literal: true

class SickDaysController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_employee
  before_action :set_sick_day, only: %i[edit update destroy]

  def index
    @sick_days = @employee.sick_days.order(period: :desc)
    @sick_days_summaries = @employee.sick_days_summaries
  end

  def new
    @sick_day = @employee.sick_days.build(period: Date.current.beginning_of_month)
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
    destroyed_period = @sick_day.period
    @sick_day.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: destroy_turbo_streams(destroyed_period) }
      format.html do
        redirect_to employee_sick_days_path(@employee), notice: 'Лікарняний успішно видалено.'
      end
    end
  end

  private

  def destroy_turbo_streams(period)
    summaries = @employee.sick_days_summaries

    [turbo_stream.remove(@sick_day), summary_turbo_stream(period, summaries)]
  end

  def summary_turbo_stream(period, summaries)
    return empty_list_turbo_stream(summaries) if summaries.empty?
    return replace_summary_turbo_stream(period, summaries) if summaries.key?(period)

    turbo_stream.remove(period_summary_id(period))
  end

  def empty_list_turbo_stream(summaries)
    turbo_stream.replace(
      'sick_days_list',
      partial: 'sick_days/list',
      locals: {
        sick_days: @employee.sick_days.order(period: :desc),
        sick_days_summaries: summaries
      }
    )
  end

  def replace_summary_turbo_stream(period, summaries)
    turbo_stream.replace(
      period_summary_id(period),
      partial: 'sick_days/summary_row',
      locals: { period: period, summaries: summaries }
    )
  end

  def period_summary_id(period)
    "summary_#{period.strftime('%Y-%m')}"
  end

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_sick_day
    @sick_day = SickDay.find(params[:id])
  end

  def sick_day_params
    params.require(:sick_day).permit(:period, :pfu_amount, :enterprise_amount,
                                     :pfu_amount_cents, :enterprise_amount_cents)
  end
end
