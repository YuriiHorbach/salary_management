module Admin
  class AdminsController < Admin::BaseController
    before_action :authenticate_user!

    def index
    end
  end
end
