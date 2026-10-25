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
      redirect_to employee_vacations_path(@vacation.employee), notice: t('flash.vacation_entries.created')
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  private

  def load_form_data
    @employee_search = params[:employee_search].to_s.strip
    if @employee_search.present?
      @employees = Employee.search_by_text(@employee_search)
                           .order(:last_name, :first_name)
                           .limit(50)
    else
      @employees = Employee.all.order(:last_name, :first_name).limit(50)
    end
  end

  def vacation_params
    params.expect(vacation: %i[employee_id period vacation_amount])
  end
end
