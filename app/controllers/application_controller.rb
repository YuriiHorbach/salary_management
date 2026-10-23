# frozen_string_literal: true

# Base controller for the application.
#
# Resolves the active UI locale from the +locale+ query parameter, exposes the
# user-selected +current_working_month+ to controllers and views, and keeps the
# active locale in generated URLs so navigation never silently switches back to
# the default language.
class ApplicationController < ActionController::Base
  include Pagy::Method

  helper_method :current_working_month

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Adds the active non-default locale to every generated URL.
  #
  # @return [Hash] locale option, or an empty hash for the default locale
  def default_url_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

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

  private

  # Applies a supported locale from the query string; unsupported or missing
  # values fall back to English.
  #
  # @return [Symbol] the locale assigned to the current request
  def set_locale
    requested = params[:locale]
    I18n.locale = supported_locale?(requested) ? requested.to_sym : I18n.default_locale
  end

  # @param locale [String, Symbol, nil] requested locale
  # @return [Boolean] whether the application ships translations for it
  def supported_locale?(locale)
    SalaryManagement::SUPPORTED_LOCALES.map(&:to_s).include?(locale.to_s)
  end
end
