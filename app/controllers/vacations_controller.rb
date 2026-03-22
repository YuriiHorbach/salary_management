# frozen_string_literal: true

class VacationsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_employee
  before_action :set_vacation, only: %i[edit update destroy]

  def index
    @vacations = @employee.vacations.order(period: :desc)
  end

  def new
    @vacation = @employee.vacations.build
  end

  def create
    @vacation = @employee.vacations.build(vacation_params)

    if @vacation.save
      # Calculate and store taxes for the vacation
      tax_calculation_result = TaxCalculator.call(
        amount_cents: @vacation.vacation_amount_cents,
        children_count: @employee.children_count,
        chaes: @employee.chaes,
        disability_group: @employee.disability_group,
        contract: @employee.contract
      )
      @vacation.update(
        income_tax_cents: tax_calculation_result[:income_tax_cents],
        military_tax_cents: tax_calculation_result[:military_tax_cents],
        net_amount_cents: tax_calculation_result[:net_amount_cents]
      )

      redirect_to employee_vacations_path(@employee), notice: 'Відпустку успішно додано.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @vacation.update(vacation_params)
      # Recalculate taxes if the vacation details change
      tax_calculation_result = TaxCalculator.call(
        amount_cents: @vacation.vacation_amount_cents,
        children_count: @employee.children_count,
        chaes: @employee.chaes,
        disability_group: @employee.disability_group,
        contract: @employee.contract
      )
      @vacation.update(
        income_tax_cents: tax_calculation_result[:income_tax_cents],
        military_tax_cents: tax_calculation_result[:military_tax_cents],
        net_amount_cents: tax_calculation_result[:net_amount_cents]
      )

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
    params.require(:vacation).permit(:period, :vacation_amount_cents)
  end
end
