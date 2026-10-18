# frozen_string_literal: true

module Reports
  class EmployeeDetailedQuery
    COLUMN_LABELS = {
      id_code: 'ІПН',
      book_code: 'Код книги',
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
      total_income: 'Загальний дохід',
      total_tax: 'Загальний податок',
      total_military: 'Загальний вз',
      net_pay: 'Чиста виплата'
    }.freeze

    TEXT_COLUMNS = %i[id_code book_code brigade department full_name].freeze

    def initialize(params = {})
      @params = params || {}
    end

    def call
      {
        employees: employee_rows,
        totals: totals_row
      }
    end

    private

    def employee_rows
      @employee_rows ||= base_employees.map do |emp|
        s = salary_aggregates[emp.id] || salary_zero
        v = vacation_aggregates[emp.id] || vacation_zero
        sk = sick_day_aggregates[emp.id] || sick_zero

        gross_vacation = s[:amount] + v[:amount]
        total_income = gross_vacation + sk[:total]
        total_tax = s[:income_tax] + v[:income_tax] + sk[:pdfo]
        total_military = s[:military_tax] + v[:military_tax] + sk[:military]
        net_pay = s[:net] + v[:net] + (sk[:total] - sk[:pdfo] - sk[:military])

        {
          id_code: emp.id_code.to_s,
          book_code: emp.account_book&.code || '—',
          brigade: emp.territory_sign&.name || '—',
          department: emp.department_employees.first&.department&.name || '—',
          full_name: emp.full_name,
          base_salary: s[:amount],
          salary_income_tax: s[:income_tax],
          salary_military_tax: s[:military_tax],
          salary_net: s[:net],
          vacation_amount: v[:amount],
          vacation_income_tax: v[:income_tax],
          vacation_military_tax: v[:military_tax],
          vacation_net: v[:net],
          sick_total: sk[:total],
          sick_pdfo: sk[:pdfo],
          sick_military: sk[:military],
          gross_vacation: gross_vacation,
          total_income: total_income,
          total_tax: total_tax,
          total_military: total_military,
          net_pay: net_pay
        }
      end
    end

    def totals_row
      rows = employee_rows
      return zero_row if rows.empty?

      COLUMN_KEYS.index_with do |key|
        rows.sum { |r| r[key] || 0 }
      end
    end

    def base_employees
      @base_employees ||= build_base_scope.to_a.uniq(&:id).sort_by(&:id_code)
    end

    def employee_ids
      @employee_ids ||= base_employees.map(&:id)
    end

    def build_base_scope
      scope = Employee.includes({ department_employees: :department }, :account_book, :territory_sign)

      scope = scope.where(territory_sign_id: @params[:brigade]) if @params[:brigade].present?
      scope = scope.where(departments: { id: @params[:department] }) if @params[:department].present?
      scope = scope.where(account_books: { code: @params[:account_book] }) if @params[:account_book].present?

      if @params[:employee_search].present?
        search = "%#{@params[:employee_search]}%"
        scope = scope.where(
          'CAST(id_code AS text) ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ? OR patronic_name ILIKE ?',
          search, search, search, search
        )
      end

      scope
    end

    def salary_aggregates
      @salary_aggregates ||= begin
        scope = Salary.where(employee_id: employee_ids)
        scope = scope.where('paid_on >= ?', @params[:date_from]) if @params[:date_from].present?
        scope = scope.where('paid_on <= ?', @params[:date_to]) if @params[:date_to].present?

        scope.group(:employee_id)
          .pluck(
            :employee_id,
            Arel.sql('COALESCE(SUM(amount_cents), 0)'),
            Arel.sql('COALESCE(SUM(income_tax_cents), 0)'),
            Arel.sql('COALESCE(SUM(military_tax_cents), 0)'),
            Arel.sql('COALESCE(SUM(net_amount_cents), 0)')
          )
          .index_by(&:first)
          .transform_values do |v|
            {
              amount: v[1] / 100.0,
              income_tax: v[2] / 100.0,
              military_tax: v[3] / 100.0,
              net: v[4] / 100.0
            }
          end
      end
    end

    def vacation_aggregates
      @vacation_aggregates ||= begin
        scope = Vacation.where(employee_id: employee_ids)
        scope = scope.where('period >= ?', @params[:date_from]) if @params[:date_from].present?
        scope = scope.where('period <= ?', @params[:date_to]) if @params[:date_to].present?

        scope.group(:employee_id)
          .pluck(
            :employee_id,
            Arel.sql('COALESCE(SUM(vacation_amount_cents), 0)'),
            Arel.sql('COALESCE(SUM(income_tax_cents), 0)'),
            Arel.sql('COALESCE(SUM(military_tax_cents), 0)'),
            Arel.sql('COALESCE(SUM(net_amount_cents), 0)')
          )
          .index_by(&:first)
          .transform_values do |v|
            {
              amount: v[1] / 100.0,
              income_tax: v[2] / 100.0,
              military_tax: v[3] / 100.0,
              net: v[4] / 100.0
            }
          end
      end
    end

    def sick_day_aggregates
      @sick_day_aggregates ||= begin
        scope = SickDay.where(employee_id: employee_ids)
        scope = scope.where('period >= ?', @params[:date_from]) if @params[:date_from].present?
        scope = scope.where('period <= ?', @params[:date_to]) if @params[:date_to].present?

        scope.group(:employee_id)
          .pluck(
            :employee_id,
            Arel.sql('COALESCE(SUM(pfu_amount_cents + enterprise_amount_cents), 0)'),
            Arel.sql('COALESCE(SUM((pfu_amount_cents + enterprise_amount_cents) * 0.18), 0)'),
            Arel.sql('COALESCE(SUM((pfu_amount_cents + enterprise_amount_cents) * 0.05), 0)')
          )
          .index_by(&:first)
          .transform_values do |v|
            {
              total: v[1] / 100.0,
              pdfo: v[2] / 100.0,
              military: v[3] / 100.0
            }
          end
      end
    end

    COLUMN_KEYS = %i[
      base_salary salary_income_tax salary_military_tax salary_net
      vacation_amount vacation_income_tax vacation_military_tax vacation_net
      sick_total sick_pdfo sick_military
      gross_vacation total_income total_tax total_military net_pay
    ].freeze

    def salary_zero
      { amount: 0.0, income_tax: 0.0, military_tax: 0.0, net: 0.0 }
    end

    def vacation_zero
      { amount: 0.0, income_tax: 0.0, military_tax: 0.0, net: 0.0 }
    end

    def sick_zero
      { total: 0.0, pdfo: 0.0, military: 0.0 }
    end

    def zero_row
      COLUMN_KEYS.index_with { 0.0 }
    end
  end
end
