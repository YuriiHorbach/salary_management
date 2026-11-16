# frozen_string_literal: true

module Reports
  # Builds an employee earnings pivot for one month.
  #
  # Every employee gets exactly one row. The salary total across all
  # departments/positions is shown in +total_salary+, while each distinct
  # department (or position inside a department) becomes its own dynamic
  # column. Salaries without a department are grouped under
  # +UNASSIGNED_DEPARTMENT+ so the grand total always matches the salary rows.
  class EmployeeEarningsQuery
    UNASSIGNED_DEPARTMENT = 'Без підрозділу'

    attr_reader :period

    # @param params [Hash, ActionController::Parameters] optional +period+
    #   (+YYYY-MM+) used to scope the report
    def initialize(params = {})
      @params = params || {}
      @period = selected_period
    end

    # @return [Hash] +:period+, +:columns+, +:rows+ and +:totals+
    def call
      {
        period: period,
        columns: build_columns,
        rows: build_rows,
        totals: { salary: total_cents / 100.0 }
      }
    end

    private

    def selected_period
      Reports::Period.parse(@params[:period])&.date || Date.current.beginning_of_month
    end

    # Salary amounts in cents grouped by employee identity, department and
    # position name.
    #
    # @return [Hash{Array => Integer}]
    def grouped_sums
      @grouped_sums ||= Salary.where(period: period)
                              .joins(:employee)
                              .left_joins(:department, :position)
                              .group('employees.id',
                                     'employees.id_code',
                                     'employees.last_name',
                                     'employees.first_name',
                                     'employees.patronic_name',
                                     'departments.name',
                                     'positions.position_name')
                              .sum('salaries.amount_cents')
    end

    # @return [Array<Hash>] one dynamic column per department/position pair
    def build_columns
      grouped_sums.keys
                  .map { |group_key| column_key_for(group_key) }
                  .uniq
                  .sort_by { |department_name, position_name| [department_name.downcase, position_name.downcase] }
                  .map { |key| column_entry(key) }
    end

    def column_entry(key)
      department_name, position_name = key

      {
        key: key,
        department_name: department_name,
        position_name: position_name,
        label: column_label(key)
      }
    end

    # @return [Array<Hash>] one row per employee, sorted by full name
    def build_rows
      rows = {}
      grouped_sums.each { |group_key, cents| accumulate(rows, group_key, cents) }

      rows.values
          .sort_by { |row| row[:full_name].downcase }
          .map { |row| finalize_row(row) }
    end

    def accumulate(rows, group_key, cents)
      employee_id, id_code, last_name, first_name, patronic_name = group_key
      row = rows[employee_id] ||= new_row(employee_id, id_code, last_name, first_name, patronic_name)

      row[:total_cents] += cents.to_i
      row[:earnings_cents][column_key_for(group_key)] += cents.to_i
    end

    def new_row(employee_id, id_code, last_name, first_name, patronic_name)
      {
        employee_id: employee_id,
        id_code: id_code.to_s,
        full_name: [last_name, first_name, patronic_name].compact_blank.join(' '),
        total_cents: 0,
        earnings_cents: Hash.new(0)
      }
    end

    def finalize_row(row)
      {
        employee_id: row[:employee_id],
        id_code: row[:id_code],
        full_name: row[:full_name],
        total_salary: row[:total_cents] / 100.0,
        earnings: row[:earnings_cents].transform_values { |cents| cents / 100.0 }
      }
    end

    def column_key_for(group_key)
      [normalize_department(group_key[5]), group_key[6].to_s]
    end

    def column_label(key)
      key.compact_blank.join(' ')
    end

    def normalize_department(name)
      name.presence || UNASSIGNED_DEPARTMENT
    end

    def total_cents
      @total_cents ||= grouped_sums.values.sum(&:to_i)
    end
  end
end
