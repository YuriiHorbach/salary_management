# frozen_string_literal: true

class Settings::BaseController < ApplicationController
  before_action :authenticate_user!
  layout 'application'
end
