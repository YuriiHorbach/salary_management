# frozen_string_literal: true

# Renders the application dashboard and lets the user choose the payroll month
# they are currently working on.
class HomePagesController < ApplicationController
  before_action :authenticate_user!

  def index; end

  def update_current_working_month
    month = parsed_working_month

    if month && current_user.update(current_working_month: month)
      redirect_to root_path, notice: t('home_pages.flash.month_saved', month: l(month, format: :short))
    else
      redirect_to root_path, alert: t('home_pages.flash.invalid_month')
    end
  end

  private

  def parsed_working_month
    Date.strptime(params[:current_working_month].to_s, '%Y-%m').beginning_of_month
  rescue Date::Error
    nil
  end
end
