class ReportsController < ApplicationController
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
    # render :salary_by_department unless params[:action] == 'index'
  end

  private

  private

  def build_report_data(salaries_relation)
    # Зверніть увагу: прибрано * 100 для колонок, що вже містять 'cents',
    # залишено * 100 лише для колонки 'amount'.

    gross = salaries_relation
            .joins(:department)
            .group('departments.name')
            .pluck('departments.name', Arel.sql('SUM(salaries.amount * 100)')) # Правильно: amount * 100
            .to_h

    net = salaries_relation
          .joins(:department)
          .group('departments.name')
          .pluck('departments.name', Arel.sql('SUM(salaries.net_amount_cents)')) # Виправлено: net_amount_cents (без * 100)
          .to_h

    pdfo = salaries_relation
           .joins(:department)
           .group('departments.name')
           .pluck('departments.name', Arel.sql('SUM(salaries.income_tax_cents)')) # Виправлено: income_tax_cents (без * 100)
           .to_h

    military_tax = salaries_relation
                   .joins(:department)
                   .group('departments.name')
                   .pluck('departments.name', Arel.sql('SUM(salaries.military_tax_cents)')) # Виправлено: military_tax_cents (без * 100)
                   .to_h

    # Комбінуємо всі чотири хеші в один, де ключ — назва відділу
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
