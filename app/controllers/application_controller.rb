# frozen_string_literal: true

# Base controller for the application.
#
# Exposes the user-selected +current_working_month+ to controllers and views so
# payroll entry forms can default to the month the user is actually working on.
class ApplicationController < ActionController::Base
  include Pagy::Method

  helper_method :current_working_month

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  # Returns the persisted working month or the calendar month when none is set.
  #
  # @return [Date] the first day of the effective working month
  def current_working_month
    current_user&.current_working_month || Date.current.beginning_of_month
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[id_code first_name patronic_name last_name])
  end
end
