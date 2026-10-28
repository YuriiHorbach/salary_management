# frozen_string_literal: true

module Reports
  # Builds the pivot data for the Summary Report.
  #
  # Data comes from +EmployeePeriodIncome+, where gross amounts and taxes are
  # already aggregated per employee, month and income type. Rows are grouped by
  # brigade (territory sign) and account book, with brigade and grand totals.
  # The report always scopes to one month; +period+ defaults to the current one.
  class SalarySummaryQuery
    # All monetary columns in UAH (converted from cents).
    COLUMN_KEYS = %i[
      salary_amount
      salary_income_tax
      salary_military_tax
      salary_net
      vacation_amount
      vacation_income_tax
      vacation_military_tax
      sick_total
      sick_pdfo
      sick_military
      total_salary
      total_income
      total_tax
      total_military
      salary_gross_vacation
      salary_vacation_income_tax
    ].freeze

    COLUMN_LABELS = {
      salary_amount: 'Зарплата',
      salary_income_tax: 'ПДФО із зарплати',
      salary_military_tax: 'ВЗ із зарплати',
      salary_net: 'Зарплата на руки',
      vacation_amount: 'Відпускні',
      vacation_income_tax: 'ПДФО з відпускних',
      vacation_military_tax: 'ВЗ з відпускних',
      sick_total: 'Лікарняні',
      sick_pdfo: 'ПДФО з лікарняних',
      sick_military: 'ВЗ з лікарняних',
      total_salary: 'Всього зарплат',
      total_income: 'Загальний дохід (зп+вп+лік)',
      total_tax: 'Загальний податок (зп+вп+лік)',
      total_military: 'Загальний ВЗ (зп+вп+лік)',
      salary_gross_vacation: 'Зарплата + відпускні (брутто)',
      salary_vacation_income_tax: 'ПДФО із зп + відпускних'
    }.freeze

    attr_reader :period

    def initialize(params = {})
      @params = params || {}
      @period = selected_period
    end

    def call
      brigades, grand_total = build_data
      {
        period: period,
        brigades: brigades,
        grand_total: grand_total
      }
    end

    private

    def selected_period
      Date.strptime(@params[:period].to_s, '%Y-%m').beginning_of_month
    rescue ArgumentError, TypeError
      Date.current.beginning_of_month
    end

    def build_data
      incomes_by_employee = EmployeePeriodIncome.for_period(period).group_by(&:employee_id)
      brigades = {}
      grand_total = zero_hash

      grouped_employees.each do |(brigade, book_code), employees|
        group_total = append_group(brigades, brigade, book_code, employees, incomes_by_employee)
        grand_total = add_hashes(grand_total, group_total)
      end

      [brigades, grand_total]
    end

    def grouped_employees
      Employee.includes(:account_book, :territory_sign)
              .group_by { |employee| [employee.territory_sign&.name.to_s, employee.account_book&.code.to_s] }
              .sort_by { |(brigade, book_code), _employees| [brigade, book_code] }
              .to_h
    end

    def append_group(brigades, brigade_name, book_code, employees, incomes_by_employee)
      brigade_data = (brigades[brigade_name] ||= { books: {}, total: zero_hash })
      brigade_data[:books][book_code] ||= zero_hash

      group_total = zero_hash
      employees.each do |employee|
        row = row_for(employee, incomes_by_employee)
        accumulate!(brigade_data, book_code, row)
        group_total = add_hashes(group_total, row)
      end
      group_total
    end

    def row_for(employee, incomes_by_employee)
      rows = (incomes_by_employee[employee.id] || []).index_by(&:income_type)
      compute_row(rows)
    end

    def accumulate!(brigade_data, book_code, row)
      brigade_data[:books][book_code] = add_hashes(brigade_data[:books][book_code], row)
      brigade_data[:total] = add_hashes(brigade_data[:total], row)
    end

    def compute_row(rows)
      salary = income_values(rows['salary'])
      vacation = income_values(rows['vacation'])
      sick = income_values(rows['sick_day'])

      base_columns(salary, vacation, sick).merge(total_columns(salary, vacation, sick))
    end

    def income_values(income)
      {
        gross: uah(income&.gross_cents),
        income_tax: uah(income&.income_tax_cents),
        military_tax: uah(income&.military_tax_cents),
        net: uah(income&.net_amount_cents)
      }
    end

    def base_columns(salary, vacation, sick)
      {
        salary_amount: salary[:gross],
        salary_income_tax: salary[:income_tax],
        salary_military_tax: salary[:military_tax],
        salary_net: salary[:net],
        vacation_amount: vacation[:gross],
        vacation_income_tax: vacation[:income_tax],
        vacation_military_tax: vacation[:military_tax],
        sick_total: sick[:gross],
        sick_pdfo: sick[:income_tax],
        sick_military: sick[:military_tax]
      }
    end

    def total_columns(salary, vacation, sick)
      salary_gross_vacation = salary[:gross] + vacation[:gross]
      salary_vacation_income_tax = salary[:income_tax] + vacation[:income_tax]

      {
        total_salary: salary[:gross],
        total_income: salary_gross_vacation + sick[:gross],
        total_tax: salary_vacation_income_tax + sick[:income_tax],
        total_military: salary[:military_tax] + vacation[:military_tax] + sick[:military_tax],
        salary_gross_vacation: salary_gross_vacation,
        salary_vacation_income_tax: salary_vacation_income_tax
      }
    end

    def uah(cents)
      cents.to_i / 100.0
    end

    def zero_hash
      COLUMN_KEYS.index_with { 0.0 }
    end

    def add_hashes(first, second)
      first.merge(second) { |_key, left, right| left + right }
    end
  end
end
