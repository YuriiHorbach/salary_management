# frozen_string_literal: true

# Standalone vacation entry form with an employee search and a monthly report frame.
#
# The report follows the +month+ query parameter so the page can show vacations for
# a different month without changing the user's persisted working month.
class VacationEntriesController < ApplicationController
  before_action :authenticate_user!

  def new
    load_form_data
    @vacation = Vacation.new(period: @report_month)
  end

  def create
    @vacation = Vacation.new(vacation_params)

    if @vacation.save
      redirect_to employee_vacations_path(@vacation.employee), notice: t('flash.vacation_entries.created')
    else
      load_form_data(month: @vacation.period)
      render :new, status: :unprocessable_content
    end
  end

  private

  # @param month [Date, nil] month to report on; defaults to the requested or working month
  def load_form_data(month: nil)
    load_employees
    @report_month = month || requested_month
  end

  def load_employees
    @employee_search = params[:employee_search].to_s.strip
    @employees = if @employee_search.present?
                   Employee.search_by_text(@employee_search)
                 else
                   Employee.all
                 end.order(:last_name, :first_name).limit(50)
  end

  # @return [Date] the month from the +month+ param, or the user's working month
  def requested_month
    Reports::Period.parse(params[:month])&.date || current_working_month
  end

  def vacation_params
    params.expect(vacation: %i[employee_id period vacation_amount])
  end
end
