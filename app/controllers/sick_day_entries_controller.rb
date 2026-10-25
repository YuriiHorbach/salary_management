# frozen_string_literal: true

class SickDayEntriesController < ApplicationController
  before_action :authenticate_user!

  def new
    load_form_data
    @sick_day = SickDay.new(period: current_working_month)
  end

  def create
    @sick_day = SickDay.new(sick_day_params)

    if @sick_day.save
      redirect_to employee_sick_days_path(@sick_day.employee), notice: t('flash.sick_day_entries.created')
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

  def sick_day_params
    params.expect(sick_day: %i[employee_id period pfu_amount enterprise_amount])
  end
end
