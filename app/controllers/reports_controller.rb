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
    @period_value = effective_period&.to_s
    @result = Reports::EmployeeDetailedQuery.new(detailed_query_params).call

    respond_to do |format|
      format.html { prepare_detailed_html }
      format.csv do
        send_csv(Reports::EmployeeDetailedCsvExporter.new(@result).call, 'detailed',
                 period: selected_period&.date)
      end
    end
  end

  def four_df
    rows = Reports::FourDfQuery.new(
      period: selected_period,
      year: params.dig(:q, :by_year),
      month: params.dig(:q, :by_month),
      department: params.dig(:q, :by_department)
    ).call
    send_csv(Reports::FourDfCsvExporter.new(rows).call, '4df', period: selected_period&.date)
  end

  private

  # Params handed to +Reports::EmployeeDetailedQuery+.
  #
  # The effective month is always written explicitly so a stale +period+ from
  # the request cannot win over an explicit date range.
  #
  # @return [ActionController::Parameters]
  def detailed_query_params
    params.merge(period: effective_period&.to_s)
  end

  # Month applied to the detailed report.
  #
  # An explicit date range always takes precedence, so the month filter is
  # disabled whenever either date boundary is present. A valid +period+ is used
  # when requested; otherwise the report falls back to the user's current
  # working month. Invalid month values are treated as absent.
  #
  # @return [Reports::Period, nil] nil when a date range is active
  def effective_period
    return @effective_period if defined?(@effective_period)

    @effective_period =
      if params[:date_from].present? || params[:date_to].present?
        nil
      else
        Reports::Period.parse(params[:period]) || Reports::Period.from_date(current_working_month)
      end
  end

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
