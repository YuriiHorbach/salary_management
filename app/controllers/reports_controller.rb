# frozen_string_literal: true

class ReportsController < ApplicationController
  DETAILED_REPORT_PER_PAGE = 20

  before_action :authenticate_user!

  def index
    @q = Salary.ransack(params[:q])
    @departments = Department.all

    salaries = @q.result(distinct: true)
                 .by_month(params.dig(:q, :by_month))
                 .by_year(params.dig(:q, :by_year))
                 .by_department(params.dig(:q, :by_department))

    @total_records = SalaryReportService.new(salaries).call

    @monthly_department_salaries = build_report_data(salaries)
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
      format.html do
        @q = Employee.ransack(params[:q])
        @departments = Department.all
        @brigades = TerritorySign.all.order(:name)
        @account_book_codes = AccountBook.available_codes
        @pagy, @employees = pagy(:offset, @result[:employees], limit: DETAILED_REPORT_PER_PAGE)
      end
      format.csv { send_csv(Reports::EmployeeDetailedCsvExporter.new(@result).call, 'detailed') }
    end
  end

  private

  def send_csv(content, prefix)
    send_data content,
              filename: "#{prefix}-#{Date.current}.csv",
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end

  def build_report_data(salaries_relation)
    gross = salaries_relation
            .joins(:department)
            .group('departments.name')
            .pluck('departments.name', Arel.sql('SUM(salaries.amount_cents)'))
            .to_h

    net = salaries_relation
          .joins(:department)
          .group('departments.name')
          .pluck('departments.name', Arel.sql('SUM(salaries.net_amount_cents)'))
          .to_h

    pdfo = salaries_relation
           .joins(:department)
           .group('departments.name')
           .pluck('departments.name', Arel.sql('SUM(salaries.income_tax_cents)'))
           .to_h

    military_tax = salaries_relation
                   .joins(:department)
                   .group('departments.name')
                   .pluck('departments.name', Arel.sql('SUM(salaries.military_tax_cents)'))
                   .to_h

    report_data = {}
    gross.each do |department_name, gross_total|
      report_data[department_name] = {
        gross: gross_total,
        net: net[department_name] || 0,
        pdfo: pdfo[department_name] || 0,
        military_tax: military_tax[department_name] || 0
      }
    end

    report_data
  end
end
