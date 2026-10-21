# frozen_string_literal: true

class VacationEntriesController < ApplicationController
  before_action :authenticate_user!

  def new
    load_form_data
    @vacation = Vacation.new(period: current_working_month)
  end

  def create
    @vacation = Vacation.new(vacation_params)

    if @vacation.save
      redirect_to employee_vacations_path(@vacation.employee), notice: 'Відпустку успішно додано.'
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

  def vacation_params
    params.expect(vacation: %i[employee_id period vacation_amount])
  end
end
