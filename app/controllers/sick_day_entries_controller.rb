# frozen_string_literal: true

# Standalone sick day entry form with an employee search and a monthly summary.
#
# The summary follows the +month+ query parameter after a save, so an entry
# created for a month other than the user's working month is immediately visible.
class SickDayEntriesController < ApplicationController
  before_action :authenticate_user!

  def new
    load_form_data
    @sick_day = SickDay.new(period: @report_month)
  end

  def create
    @sick_day = SickDay.new(sick_day_params)

    if @sick_day.save
      redirect_to new_sick_day_entry_path(month: @sick_day.period.strftime('%Y-%m')),
                  notice: t('flash.sick_day_entries.created')
    else
      load_form_data(month: @sick_day.period)
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

  def sick_day_params
    params.expect(sick_day: %i[employee_id period pfu_amount enterprise_amount])
  end
end
