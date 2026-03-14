# frozen_string_literal: true

class VacationsController < ApplicationController
  def index
    @vacations = Vacation.includes(:employee).all
  end
end
