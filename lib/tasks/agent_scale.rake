# frozen_string_literal: true

require 'benchmark'
require 'digest'

# Helpers for the agent-only scale seed and performance baseline tasks.
#
# This module is intentionally kept outside application code: it creates
# synthetic payroll data and measures read paths without changing report,
# controller, or model behaviour.
module AgentScale
  EMPLOYEES_PER_SCALE = 60
  BATCH_SIZE = 1_000
  CHILDREN_COUNTS = [0, 0, 0, 1, 1, 2, 3].freeze
  DISABILITY_GROUPS = [1, 2, 3].freeze

  module_function

  # Aborts unless the connected database is an isolated agent database.
  #
  # @return [void]
  def ensure_agent_database!
    database = ActiveRecord::Base.connection_db_config.database.to_s
    return if database.end_with?('_agent')

    abort "Відмова: база #{database.inspect} не закінчується на '_agent'."
  end

  # Applies flat-rate payroll taxes to a gross amount.
  #
  # @param gross_cents [Integer]
  # @param settings [TaxSetting] rates to apply
  # @return [Array(Integer, Integer, Integer)] income tax, military tax, net
  def tax_for(gross_cents, settings)
    income = (gross_cents * settings.income_rate).round
    military = (gross_cents * settings.military_rate).round
    [income, military, gross_cents - income - military]
  end

  # @param settings [TaxSetting] rates used for the synthetic rows
  # @return [String] digest of the tax settings
  def digest(settings)
    attributes = settings.slice(:income_rate, :military_rate, :gran_dohid_uah, :psp_uah)
    Digest::SHA256.hexdigest(attributes.to_json)
  end

  # Inserts rows in batches to stay below PostgreSQL parameter limits.
  #
  # @param model [Class] ActiveRecord model
  # @param rows [Array<Hash>]
  # @return [void]
  # rubocop:disable Rails/SkipsModelValidations -- synthetic seed rows bypass callbacks by design
  def insert_batches(model, rows)
    rows.each_slice(BATCH_SIZE) { |batch| model.insert_all(batch) }
  end
  # rubocop:enable Rails/SkipsModelValidations

  # Measures wall-clock time and uncached SQL queries for a block.
  #
  # @param label [String]
  # @return [Array(String, Float, Integer)] label, seconds, SQL query count
  def measure(label, &block)
    sql_count = 0
    callback = lambda do |_name, _started, _finished, _id, payload|
      sql_count += 1 unless payload[:cached] || payload[:name] == 'SCHEMA'
    end

    seconds = Benchmark.realtime do
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)
    end

    [label, seconds, sql_count]
  end

  # @param value [String] "YYYY-MM"
  # @return [Date] first day of the requested month
  def parse_period(value)
    Date.strptime(value.to_s, '%Y-%m').beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end
end

namespace :agent do
  desc 'Seed synthetic scale data: 60 * SCALE employees with 12 months of payroll. Agent DB only.'
  task seed_scale: :environment do
    AgentScale.ensure_agent_database!

    scale = Integer(ENV.fetch('SCALE', '20'), exception: false)
    abort 'SCALE має бути додатним цілим числом.' unless scale&.positive?

    total = scale * AgentScale::EMPLOYEES_PER_SCALE
    abort 'SCALE завеликий (максимум 1666).' if total > 99_999

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    srand(20_260_000 + scale)

    today = Date.current
    months = (0..11).map { |offset| (today.beginning_of_month - offset.months) }
    tax_settings = TaxSetting.current

    departments = Array.new(6) do |index|
      Department.find_or_create_by!(name: "Scale Department #{index + 1}")
    end

    brigades = Array.new(5) do |index|
      TerritorySign.find_or_create_by!(name: "Scale Brigade #{index + 1}")
    end

    id_codes = Array.new(total) do |index|
      format('%<birthday>05d%<index>05d', birthday: 18_000 + (index % 6_000), index: index)
    end

    existing_codes = Employee.where(id_code: id_codes).pluck(:id_code).to_set
    new_codes = id_codes.reject { |code| existing_codes.include?(code) }

    if new_codes.empty?
      puts 'Нових працівників немає: scale-дані для цього SCALE вже створені.'
      next
    end

    code_to_index = id_codes.each_with_index.to_h
    now = Time.current
    first_names = %w[Олександр Андрій Іван Петро Микола Василь Сергій Олег Тарас Богдан]
    last_names = %w[Шевченко Коваль Бондаренко Мельник Ткаченко Кравець Лисенко Мороз]

    book_codes = new_codes.map { |code| "S#{code}" }
    existing_book_codes = AccountBook.where(code: book_codes).pluck(:code).to_set
    new_book_codes = book_codes.reject { |code| existing_book_codes.include?(code) }

    account_book_rows = new_book_codes.map do |code|
      { code: code, created_at: now, updated_at: now }
    end
    AgentScale.insert_batches(AccountBook, account_book_rows)
    account_book_ids = AccountBook.where(code: book_codes).pluck(:code, :id).to_h

    employee_rows = new_codes.map do |code|
      index = code_to_index.fetch(code)

      {
        id_code: code,
        first_name: first_names[index % first_names.size],
        patronic_name: "Patronic#{index}",
        last_name: last_names[index % last_names.size],
        children_count: AgentScale::CHILDREN_COUNTS.sample,
        disability_group: rand < 0.06 ? AgentScale::DISABILITY_GROUPS.sample : nil,
        chaes: rand < 0.04,
        territory_info: '',
        contract: rand < 0.15,
        birthday: Date.new(1899, 12, 31) + code[0, 5].to_i,
        territory_sign_id: brigades[index % brigades.size].id,
        account_book_id: account_book_ids.fetch("S#{code}"),
        identifier: "S#{code}",
        created_at: now,
        updated_at: now
      }
    end

    # rubocop:disable Rails/SkipsModelValidations -- synthetic seed rows bypass callbacks by design
    Employee.insert_all(employee_rows)
    # rubocop:enable Rails/SkipsModelValidations
    employees = Employee.where(id_code: new_codes).pluck(:id, :id_code).to_h { |id, code| [code, id] }

    assignment_rows = new_codes.map do |code|
      index = code_to_index.fetch(code)
      {
        employee_id: employees.fetch(code),
        department_id: departments[index % departments.size].id,
        position_id: nil,
        created_at: now,
        updated_at: now
      }
    end
    AgentScale.insert_batches(DepartmentEmployee, assignment_rows)

    salary_rows = []
    vacation_rows = []
    sick_rows = []
    income_totals = Hash.new(0)

    new_codes.each do |code|
      employee_id = employees.fetch(code)
      index = code_to_index.fetch(code)
      department_id = departments[index % departments.size].id
      base = rand(6_000..40_000)

      months.each do |month|
        gross = (base * (0.95 + (rand * 0.1)) * 100).round
        income, military, net = AgentScale.tax_for(gross, tax_settings)

        salary_rows << {
          employee_id: employee_id,
          department_id: department_id,
          position_id: nil,
          period: month,
          paid_on: Time.zone.local(month.year, month.month, 10, 12),
          amount_cents: gross,
          income_tax_cents: income,
          military_tax_cents: military,
          net_amount_cents: net,
          created_at: now,
          updated_at: now
        }
        income_totals[[employee_id, month, 'salary']] += gross
      end

      if rand < 0.30
        months.sample(rand(1..3)).each do |month|
          gross = rand(4_000..18_000) * 100
          income, military, net = AgentScale.tax_for(gross, tax_settings)

          vacation_rows << {
            employee_id: employee_id,
            department_id: department_id,
            period: month,
            vacation_amount_cents: gross,
            income_tax_cents: income,
            military_tax_cents: military,
            net_amount_cents: net,
            created_at: now,
            updated_at: now
          }
          income_totals[[employee_id, month, 'vacation']] += gross
        end
      end

      next unless rand < 0.25

      months.sample(rand(1..2)).each do |month|
        pfu = rand(2_500..9_000) * 100
        enterprise = rand(500..3_000) * 100
        gross = pfu + enterprise
        income, military, net = AgentScale.tax_for(gross, tax_settings)

        sick_rows << {
          employee_id: employee_id,
          department_id: department_id,
          period: month.to_s,
          pfu_amount_cents: pfu,
          enterprise_amount_cents: enterprise,
          income_tax_cents: income,
          military_tax_cents: military,
          net_amount_cents: net,
          created_at: now,
          updated_at: now
        }
        income_totals[[employee_id, month, 'sick_day']] += gross
      end
    end

    income_rows = income_totals.map do |(employee_id, month, income_type), gross|
      income, military, net = AgentScale.tax_for(gross, tax_settings)

      {
        employee_id: employee_id,
        period: month,
        income_type: income_type,
        gross_cents: gross,
        income_tax_cents: income,
        military_tax_cents: military,
        net_amount_cents: net,
        tax_settings_digest: AgentScale.digest(tax_settings),
        created_at: now,
        updated_at: now
      }
    end

    ActiveRecord::Base.transaction do
      AgentScale.insert_batches(Salary, salary_rows)
      AgentScale.insert_batches(Vacation, vacation_rows)
      AgentScale.insert_batches(SickDay, sick_rows)
      AgentScale.insert_batches(EmployeePeriodIncome, income_rows)
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    puts format(
      'Scale seed done: +%<employees>d employees, %<salaries>d salaries, %<vacations>d vacations, ' \
      '%<sick_days>d sick days, %<income_rows>d income rows in %<elapsed>.2fs',
      employees: new_codes.size, salaries: salary_rows.size, vacations: vacation_rows.size,
      sick_days: sick_rows.size, income_rows: income_rows.size, elapsed: elapsed
    )
    puts "Totals: employees=#{Employee.count}, salaries=#{Salary.count}, " \
         "vacations=#{Vacation.count}, sick_days=#{SickDay.count}, " \
         "period_incomes=#{EmployeePeriodIncome.count}"
  end
end
