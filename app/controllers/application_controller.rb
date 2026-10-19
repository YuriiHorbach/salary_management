# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Method

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[id_code first_name patronic_name last_name])
  end
end
