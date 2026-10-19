# frozen_string_literal: true

class SickDayEntriesController < ApplicationController
  before_action :authenticate_user!

  def new
    load_form_data
    @sick_day = SickDay.new(period: Date.current.beginning_of_month)
  end

  def create
    @sick_day = SickDay.new(sick_day_params)

    if @sick_day.save
      redirect_to employee_sick_days_path(@sick_day.employee), notice: 'Лікарняний успішно додано.'
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  private

  def load_form_data
    @employee_search = params[:employee_search].to_s.strip
    @employees = Employee.search_by_id_code_or_name(@employee_search).order(:last_name, :first_name)
  end

  def sick_day_params
    params.expect(sick_day: %i[employee_id period pfu_amount enterprise_amount])
  end
end
