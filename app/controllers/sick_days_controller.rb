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
      # Calculate and store taxes for the sick day
      tax_calculation_result = TaxCalculator.call(
        amount_cents: @sick_day.pfu_amount_cents + @sick_day.enterprise_amount_cents,
        children_count: @employee.children_count,
        chaes: @employee.chaes,
        disability_group: @employee.disability_group,
        contract: @employee.contract
      )
      @sick_day.update(
        income_tax_cents: tax_calculation_result[:income_tax_cents],
        military_tax_cents: tax_calculation_result[:military_tax_cents],
        net_amount_cents: tax_calculation_result[:net_amount_cents]
      )

      redirect_to employee_sick_days_path(@employee), notice: 'Лікарняний успішно додано.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @sick_day.update(sick_day_params)
      # Recalculate taxes if the sick day details change
      tax_calculation_result = TaxCalculator.call(
        amount_cents: @sick_day.pfu_amount_cents + @sick_day.enterprise_amount_cents,
        children_count: @employee.children_count,
        chaes: @employee.chaes,
        disability_group: @employee.disability_group,
        contract: @employee.contract
      )
      @sick_day.update(
        income_tax_cents: tax_calculation_result[:income_tax_cents],
        military_tax_cents: tax_calculation_result[:military_tax_cents],
        net_amount_cents: tax_calculation_result[:net_amount_cents]
      )

      redirect_to employee_sick_days_path(@employee), notice: 'Лікарняний успішно оновлено.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @sick_day.destroy

    redirect_to employee_sick_days_path(@employee), notice: 'Лікарняний успішно видалено.',
                                                  turb_stream: turbo_stream.remove(@sick_day)
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
