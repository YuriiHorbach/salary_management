# frozen_string_literal: true

class ReportsController < ApplicationController
  DETAILED_REPORT_PER_PAGE = 20

  before_action :authenticate_user!

  def index
    @q = Salary.ransack(params[:q])
    @departments = Department.all

    report = SalaryReportService.new(filtered_salaries(@q.result))
    @total_records = report.call
    @monthly_department_salaries = report.department_totals
  end

  def summary
    @result = Reports::SalarySummaryQuery.new(params).call

    respond_to do |format|
      format.html
      format.csv do
        send_csv(Reports::SalarySummaryCsvExporter.new(@result).call, 'summary',
                 period: @result[:period])
      end
    end
  end

  def detailed
    @result = Reports::EmployeeDetailedQuery.new(params).call

    respond_to do |format|
      format.html { prepare_detailed_html }
      format.csv do
        send_csv(Reports::EmployeeDetailedCsvExporter.new(@result).call, 'detailed',
                 period: selected_period&.date)
      end
    end
  end

  def four_df
    period = selected_period
    rows = Reports::FourDfQuery.new(
      year: period&.year || params.dig(:q, :by_year),
      month: period&.month || params.dig(:q, :by_month),
      department: params.dig(:q, :by_department)
    ).call
    send_csv(Reports::FourDfCsvExporter.new(rows).call, '4df', period: period&.date)
  end

  private

  def filtered_salaries(scope = Salary.ransack(params[:q]).result)
    scope = apply_selected_period(scope)
    scope.by_department(params.dig(:q, :by_department))
  end

  def apply_selected_period(scope)
    return scope.by_month(params.dig(:q, :by_month)).by_year(params.dig(:q, :by_year)) unless selected_period

    scope.by_year(selected_period.year).by_month(selected_period.month)
  end

  # @return [Reports::Period, nil]
  def selected_period
    @selected_period ||= Reports::Period.parse(params[:period])
  end

  def prepare_detailed_html
    @q = Employee.ransack(params[:q])
    @departments = Department.all
    @positions = Position.order(:position_name)
    @positions = @positions.where(department_id: params[:department]) if params[:department].present?
    @brigades = TerritorySign.all.order(:name)
    @account_book_codes = AccountBook.available_codes
    @pagy, @employees = pagy(:offset, @result[:employees], limit: DETAILED_REPORT_PER_PAGE)
  end

  def send_csv(content, prefix, period: nil)
    filename_period = period&.strftime('%Y-%m') || Date.current.to_s
    send_data content,
              filename: "#{prefix}-#{filename_period}.csv",
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end
end
