# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :admin_only

    protected

    def admin_only
      return if current_user&.admin?

      flash[:danger] = "Access denied. You don't have admin`s` rights."
      redirect_to root_path
    end
  end
end
