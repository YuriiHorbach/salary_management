# frozen_string_literal: true

module Reports
  # Builds the detailed payroll report rows and totals for the active filters.
  #
  # Employee search uses the precomputed +search_text+ column so partial,
  # multi-word and Cyrillic case-insensitive lookups work under any collation.
  class EmployeeDetailedQuery
    COLUMN_LABELS = {
      id_code: 'ІПН',
      book_code: 'Код книги',
      page_number: 'Номер на сторінці',
      brigade: 'Бригада',
      department: 'Підрозділ',
      full_name: 'ПІБ',
      base_salary: 'Базова зп',
      salary_income_tax: 'зп податок',
      salary_military_tax: 'зп вз',
      salary_net: 'зп чиста',
      vacation_amount: 'відпускні',
      vacation_income_tax: 'відп податок',
      vacation_military_tax: 'відп вз',
      sick_total: 'лікарняні',
      sick_pdfo: 'лік податок',
      sick_military: 'лік вз',
      gross_vacation: 'Брутто зп+відп',
      gross_vacation_income_tax: 'ПДФО із зп+відп',
      gross_vacation_military_tax: 'ВЗ із зп+відп',
      total_income: 'Загальний дохід',
      total_tax: 'Загальний податок',
      total_military: 'Загальний вз',
      net_pay: 'Чиста виплата'
    }.freeze

    TEXT_COLUMNS = %i[id_code book_code page_number brigade department full_name].freeze

    def initialize(params = {})
      @params = params || {}
    end

    def call
      {
        employees: sorted_employee_rows,
        totals: totals_row
      }
    end

    private

    def sorted_employee_rows
      @sorted_employee_rows ||= begin
        key, direction = sort_key_and_direction

        if key
          sorted = employee_rows.sort_by do |row|
            [sortable_value(row[key], key), row[:id_code]]
          end
          direction == 'desc' ? sorted.reverse : sorted
        else
          employee_rows
        end
      end
    end

    def sort_key_and_direction
      key, direction = sort_param.to_s.split(/\s+/, 2)
      return [nil, nil] unless COLUMN_LABELS.key?(key&.to_sym)

      [key.to_sym, direction.to_s.downcase == 'desc' ? 'desc' : 'asc']
    end

    def sort_param
      query = @params[:q] || @params['q']
      return if query.blank?

      query[:s] || query['s']
    end

    def sortable_value(value, key)
      TEXT_COLUMNS.include?(key) ? value.to_s.downcase : value.to_f
    end

    def employee_rows
      @employee_rows ||= base_employees.map { |employee| employee_row(employee) }
    end

    def employee_row(employee)
      incomes = period_incomes.fetch(employee.id, {})
      salary = incomes.fetch('salary', zero_income)
      vacation = incomes.fetch('vacation', zero_income)
      sick = incomes.fetch('sick_day', zero_income)

      identity_columns(employee).merge(income_columns(salary, vacation, sick, employee))
    end

    def identity_columns(employee)
      {
        employee_id: employee.id,
        id_code: employee.id_code.to_s,
        book_code: employee.account_book&.code || '—',
        page_number: employee.page_number.to_s,
        brigade: employee.territory_sign&.name || '—',
        department: employee.department_employees.first&.department&.name || '—',
        full_name: employee.full_name
      }
    end

    def income_columns(salary, vacation, sick, employee)
      salary_columns(salary)
        .merge(vacation_columns(vacation))
        .merge(sick_columns(sick))
        .merge(total_columns(salary, vacation, sick, employee))
    end

    def salary_columns(salary)
      {
        base_salary: salary[:amount],
        salary_income_tax: salary[:income_tax],
        salary_military_tax: salary[:military_tax],
        salary_net: salary[:net]
      }
    end

    def vacation_columns(vacation)
      {
        vacation_amount: vacation[:amount],
        vacation_income_tax: vacation[:income_tax],
        vacation_military_tax: vacation[:military_tax],
        vacation_net: vacation[:net]
      }
    end

    def sick_columns(sick)
      {
        sick_total: sick[:amount],
        sick_pdfo: sick[:income_tax],
        sick_military: sick[:military_tax]
      }
    end

    # Salary and vacation are taxed together, so the PSP and its threshold apply
    # to their combined gross instead of each income type separately. Sick leave
    # keeps its own flat-rate taxes and is only added afterwards.
    def total_columns(salary, vacation, sick, employee)
      gross_cents = salary[:gross_cents] + vacation[:gross_cents]
      tax = Reports::SalaryVacationTaxCalculator.call(
        employee: employee,
        gross_cents: gross_cents,
        settings: tax_settings
      )

      combined_columns(gross_cents, tax).merge(overall_columns(gross_cents, tax, sick))
    end

    def combined_columns(gross_cents, tax)
      {
        gross_vacation: uah(gross_cents),
        gross_vacation_income_tax: uah(tax[:income_tax_cents]),
        gross_vacation_military_tax: uah(tax[:military_tax_cents])
      }
    end

    def overall_columns(gross_cents, tax, sick)
      {
        total_income: uah(gross_cents + sick[:gross_cents]),
        total_tax: uah(tax[:income_tax_cents] + sick[:income_tax_cents]),
        total_military: uah(tax[:military_tax_cents] + sick[:military_tax_cents]),
        net_pay: uah(tax[:net_amount_cents] + sick[:net_cents])
      }
    end

    def totals_row
      rows = employee_rows
      return zero_row if rows.empty?

      COLUMN_KEYS.index_with do |key|
        rows.sum { |r| r[key] || 0 }
      end
    end

    def base_employees
      @base_employees ||= build_base_scope
                          .order(:last_name, :first_name, :id_code)
                          .to_a
                          .uniq(&:id)
    end

    def employee_ids
      @employee_ids ||= base_employees.map(&:id)
    end

    def build_base_scope
      scope = Employee.includes({ department_employees: :department }, :account_book, :territory_sign)

      scope = scope.where(territory_sign_id: @params[:brigade]) if @params[:brigade].present?
      scope = scope.where(departments: { id: @params[:department] }) if @params[:department].present?
      scope = scope.where(account_books: { code: @params[:account_book] }) if @params[:account_book].present?
      scope = filter_by_position(scope)

      if @params[:employee_search].present?
        # search_text is precomputed and downcased in Ruby, so it also works
        # under PostgreSQL's C collation where ILIKE does not fold Cyrillic.
        scope = scope.search_by_text(@params[:employee_search])
      end

      scope
    end

    def filter_by_position(scope)
      return scope if @params[:position].blank?

      assignments = DepartmentEmployee.where(position_id: @params[:position])
      assignments = assignments.where(department_id: @params[:department]) if @params[:department].present?

      scope.where(id: assignments.select(:employee_id))
    end

    def period_incomes
      @period_incomes ||= EmployeePeriodIncome.where(employee_id: employee_ids, period: period_range)
                                              .group_by(&:employee_id)
                                              .transform_values do |rows|
                                                rows.index_by(&:income_type).transform_values { |row| income_hash(row) }
                                              end
    end

    def income_hash(row)
      {
        gross_cents: row.gross_cents.to_i,
        income_tax_cents: row.income_tax_cents.to_i,
        military_tax_cents: row.military_tax_cents.to_i,
        net_cents: row.net_amount_cents.to_i,
        amount: uah(row.gross_cents),
        income_tax: uah(row.income_tax_cents),
        military_tax: uah(row.military_tax_cents),
        net: uah(row.net_amount_cents)
      }
    end

    def uah(cents)
      cents.to_i / 100.0
    end

    def tax_settings
      @tax_settings ||= TaxSetting.current
    end

    def period_range
      from = @params[:date_from].present? ? @params[:date_from].to_date.beginning_of_month : Date.new(1900, 1, 1)
      to = @params[:date_to].present? ? @params[:date_to].to_date.end_of_month : Date.new(2999, 12, 31)

      from..to
    end

    COLUMN_KEYS = %i[
      base_salary salary_income_tax salary_military_tax salary_net
      vacation_amount vacation_income_tax vacation_military_tax vacation_net
      sick_total sick_pdfo sick_military
      gross_vacation gross_vacation_income_tax gross_vacation_military_tax
      total_income total_tax total_military net_pay
    ].freeze

    def zero_income
      {
        gross_cents: 0,
        income_tax_cents: 0,
        military_tax_cents: 0,
        net_cents: 0,
        amount: 0.0,
        income_tax: 0.0,
        military_tax: 0.0,
        net: 0.0
      }
    end

    def zero_row
      COLUMN_KEYS.index_with { 0.0 }
    end
  end
end
