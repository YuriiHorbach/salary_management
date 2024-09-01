# frozen_string_literal: true

module Admin
  # Controller for managing users in the admin panel.
  #
  # This controller handles CRUD operations for users in the admin namespace.
  class UsersController < Admin::BaseController
    def index
      @users = User.all
    end

    def destroy
      @user = User.find(params[:id])
      @user.destroy
      redirect_to admin_users_path, notice: 'User deleted.'
    end
  end
end