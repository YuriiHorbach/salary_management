# frozen_string_literal: true

class ReportsController < ApplicationController
  DETAILED_REPORT_PER_PAGE = 20

  before_action :authenticate_user!

  def index
    @q = Salary.ransack(params[:q])
    @departments = Department.all

    salaries = @q.result
                 .by_month(params.dig(:q, :by_month))
                 .by_year(params.dig(:q, :by_year))
                 .by_department(params.dig(:q, :by_department))

    report = SalaryReportService.new(salaries)
    @total_records = report.call
    @monthly_department_salaries = report.department_totals
  end

  def summary
    @result = Reports::SalarySummaryQuery.new(params).call

    respond_to do |format|
      format.html
      format.csv { send_csv(Reports::SalarySummaryCsvExporter.new(@result).call, 'summary') }
    end
  end

  def detailed
    @result = Reports::EmployeeDetailedQuery.new(params).call

    respond_to do |format|
      format.html { prepare_detailed_html }
      format.csv { send_csv(Reports::EmployeeDetailedCsvExporter.new(@result).call, 'detailed') }
    end
  end

  private

  def prepare_detailed_html
    @q = Employee.ransack(params[:q])
    @departments = Department.all
    @positions = Position.order(:position_name)
    @positions = @positions.where(department_id: params[:department]) if params[:department].present?
    @brigades = TerritorySign.all.order(:name)
    @account_book_codes = AccountBook.available_codes
    @pagy, @employees = pagy(:offset, @result[:employees], limit: DETAILED_REPORT_PER_PAGE)
  end

  def send_csv(content, prefix)
    send_data content,
              filename: "#{prefix}-#{Date.current}.csv",
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end
end
