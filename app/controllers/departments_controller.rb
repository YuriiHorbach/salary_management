# frozen_string_literal: true

class DepartmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department, only: %i[edit update show]

  def index
    @departments = Department.all
  end

  def new
    @department = Department.new
  end

  def show
    now = Time.current
    @department_total = @department.salaries
                                    .where(paid_on: now.beginning_of_month..now)
                                    .sum(:amount_cents) / 100.0
  end

  def edit; end

  def create
    @department = Department.new(department_params)
    if @department.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: 'Listing was successfully created.' }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @department.update(department_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: 'Department updated successfully!' }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name)
  end
end
