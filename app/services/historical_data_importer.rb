# frozen_string_literal: true

require 'csv'

# Imports historical salary, sick-day and vacation rows from a CSV file.
#
# Individual rows are written with low-level inserts/updates (insert_all and
# update_columns) so ActiveRecord callbacks never run: the values from the file,
# including taxes, are stored as-is and are not recalculated by +TaxCalculator+.
#
# Once all rows are stored, the aggregated +EmployeePeriodIncome+ rows for each
# touched employee, month and income type are rebuilt through
# +Incomes::PeriodRecalculator+. Reports read those aggregates instead of the
# individual records, so without this step imported data would be invisible in
# the reports. Recalculation runs +TaxCalculator+ on the monthly total, while the
# imported per-record taxes stay untouched.
#
# A salary row is matched to an existing record by employee, month, department
# and position (position is always nil for imports), which mirrors the
# uniqueness rules in +Salary+. This keeps several salaries of the same employee
# and month in different departments instead of overwriting them. Sick-day and
# vacation rows are matched by employee, month and department.
class HistoricalDataImporter
  Result = Struct.new(:created, :updated, :skipped, :errors, keyword_init: true) do
    def imported
      created + updated
    end
  end

  TYPE_ALIASES = {
    'salary' => :salary,
    'зарплата' => :salary,
    'зарплати' => :salary,
    'sick' => :sick_day,
    'sick_day' => :sick_day,
    'sick_days' => :sick_day,
    'лікарняний' => :sick_day,
    'лікарняні' => :sick_day,
    'vacation' => :vacation,
    'vacations' => :vacation,
    'відпустка' => :vacation,
    'відпустки' => :vacation,
    'відпускні' => :vacation
  }.freeze

  HEADER_ALIASES = {
    'type' => 'type', 'тип' => 'type',
    'id_code' => 'id_code', 'ід_код' => 'id_code', 'іпн' => 'id_code', 'ipn' => 'id_code',
    'passport' => 'id_code', 'паспорт' => 'id_code', 'рнокпп' => 'id_code', 'rnokpp' => 'id_code',
    'identifier' => 'identifier', 'book_code' => 'identifier', 'код_книги' => 'identifier',
    'period' => 'period', 'період' => 'period', 'місяць' => 'period', 'month' => 'period',
    'amount' => 'amount', 'сума' => 'amount', 'зарплата' => 'amount', 'нараховано' => 'amount',
    'gross' => 'amount',
    'pfu_amount' => 'pfu_amount', 'пфу' => 'pfu_amount', 'сума_пфу' => 'pfu_amount',
    'enterprise_amount' => 'enterprise_amount', 'підприємство' => 'enterprise_amount',
    'сума_підприємства' => 'enterprise_amount',
    'vacation_amount' => 'vacation_amount', 'відпускні' => 'vacation_amount',
    'income_tax' => 'income_tax', 'пдфо' => 'income_tax', 'податок' => 'income_tax',
    'military_tax' => 'military_tax', 'вз' => 'military_tax', 'військовий_збір' => 'military_tax',
    'net_amount' => 'net_amount', 'чиста_виплата' => 'net_amount', 'на_руки' => 'net_amount',
    'department' => 'department', 'підрозділ' => 'department',
    'department_id' => 'department',
    'paid_on' => 'paid_on', 'дата_виплати' => 'paid_on'
  }.freeze

  def initialize(content, type: nil)
    @content = content
    @default_type = type.presence
  end

  # Runs the import and rebuilds the period-income aggregates afterwards.
  #
  # @return [Result] counts of created, updated and skipped rows plus per-row
  #   error messages.
  def call
    result = Result.new(created: 0, updated: 0, skipped: 0, errors: [])
    @touched_incomes = {}
    table = parse_csv

    if table.headers.compact.empty?
      result.errors << I18n.t('historical_imports.errors.no_headers')
      return result
    end

    table.each.with_index(2) do |row, line_number|
      process_row(normalize_row(row), line_number, result)
    end

    recalculate_period_incomes
    result
  end

  private

  def parse_csv
    CSV.parse(utf8(@content), headers: true, col_sep: separator, liberal_parsing: true)
  end

  def utf8(content)
    string = content.to_s.dup.force_encoding('UTF-8')
    return string if string.valid_encoding?

    string.encode('UTF-8', 'Windows-1251', invalid: :replace, undef: :replace)
  end

  def separator
    first_line = utf8(@content).lines.first.to_s
    first_line.count(';') >= first_line.count(',') ? ';' : ','
  end

  def normalize_row(row)
    row.to_h.each_with_object({}) do |(header, value), attributes|
      key = HEADER_ALIASES[normalize_header(header)]
      attributes[key] = value if key
    end
  end

  def normalize_header(header)
    header.to_s.delete_prefix("\uFEFF").strip.downcase.gsub(/\s+/, '_')
  end

  def process_row(attributes, line_number, result)
    type = normalize_type(attributes['type']) || normalize_type(@default_type)

    return skip(result, line_number, I18n.t('historical_imports.errors.unknown_type')) unless type

    employee_id = employee_id_for(attributes)

    unless employee_id
      return skip(result, line_number,
                  I18n.t('historical_imports.errors.employee_not_found', code: identifier_for(attributes).inspect))
    end

    period = ValueParser.period(attributes['period'])
    unless period
      return skip(result, line_number,
                  I18n.t('historical_imports.errors.invalid_period',
                         period: attributes['period'].inspect))
    end

    store_row(type, attributes, employee_id, period, result)
  end

  def store_row(type, attributes, employee_id, period, result)
    case type
    when :salary then store_salary(attributes, employee_id, period, result)
    when :sick_day then store_sick_day(attributes, employee_id, period, result)
    when :vacation then store_vacation(attributes, employee_id, period, result)
    end
  end

  def store_salary(attributes, employee_id, period, result)
    gross = ValueParser.cents(attributes['amount'])
    income = ValueParser.cents(attributes['income_tax'])
    military = ValueParser.cents(attributes['military_tax'])
    net = net_amount(attributes, gross, income, military)
    department_id = department_id_for(attributes['department'])

    store(
      model: Salary,
      attributes: {
        employee_id: employee_id,
        department_id: department_id,
        amount_cents: gross,
        income_tax_cents: income,
        military_tax_cents: military,
        net_amount_cents: net,
        period: period,
        paid_on: ValueParser.date(attributes['paid_on']) || period
      },
      # Mirrors Salary#period_unique_within_scope: one salary per position, or
      # per department when no position is selected.
      identity: {
        employee_id: employee_id,
        period: period,
        department_id: department_id,
        position_id: nil
      },
      income_type: 'salary',
      result: result
    )
  end

  def store_sick_day(attributes, employee_id, period, result)
    pfu = ValueParser.cents(attributes['pfu_amount'])
    enterprise = ValueParser.cents(attributes['enterprise_amount'])
    gross = pfu + enterprise
    income = ValueParser.cents(attributes['income_tax'])
    military = ValueParser.cents(attributes['military_tax'])
    net = net_amount(attributes, gross, income, military)
    department_id = department_id_for(attributes['department'])

    store(
      model: SickDay,
      attributes: {
        employee_id: employee_id,
        department_id: department_id,
        pfu_amount_cents: pfu,
        enterprise_amount_cents: enterprise,
        income_tax_cents: income,
        military_tax_cents: military,
        net_amount_cents: net,
        period: period
      },
      identity: {
        employee_id: employee_id,
        period: period,
        department_id: department_id
      },
      income_type: 'sick_day',
      result: result
    )
  end

  def store_vacation(attributes, employee_id, period, result)
    gross = ValueParser.cents(attributes['vacation_amount'])
    income = ValueParser.cents(attributes['income_tax'])
    military = ValueParser.cents(attributes['military_tax'])
    net = net_amount(attributes, gross, income, military)
    department_id = department_id_for(attributes['department'])

    store(
      model: Vacation,
      attributes: {
        employee_id: employee_id,
        department_id: department_id,
        vacation_amount_cents: gross,
        income_tax_cents: income,
        military_tax_cents: military,
        net_amount_cents: net,
        period: period
      },
      identity: {
        employee_id: employee_id,
        period: period,
        department_id: department_id
      },
      income_type: 'vacation',
      result: result
    )
  end

  # insert_all/update_columns bypass validations and callbacks on purpose, so
  # imported taxes stay exactly as they are in the CSV. The touched
  # (employee, period, income type) triple is remembered so the aggregates can be
  # rebuilt once the whole file has been processed.
  # rubocop:disable Rails/SkipsModelValidations
  def store(model:, attributes:, identity:, income_type:, result:)
    existing = model.find_by(identity)

    if existing
      existing.update_columns(attributes.merge(updated_at: Time.current))
      result.updated += 1
    else
      now = Time.current
      model.insert_all([attributes.merge(created_at: now, updated_at: now)])
      result.created += 1
    end

    @touched_incomes[[attributes[:employee_id], attributes[:period], income_type]] = true
  end
  # rubocop:enable Rails/SkipsModelValidations

  # Rebuilds +EmployeePeriodIncome+ once per touched employee, month and income
  # type so reports include the imported rows. Taxes are calculated on the
  # monthly total, not on each CSV row.
  def recalculate_period_incomes
    @touched_incomes.each_key do |employee_id, period, income_type|
      Incomes::PeriodRecalculator.call(
        employee: employee_record(employee_id),
        period: period,
        income_type: income_type
      )
    end
  end

  def employee_record(employee_id)
    (@employee_records ||= {})[employee_id] ||= Employee.find(employee_id)
  end

  def net_amount(attributes, gross, income, military)
    return ValueParser.cents(attributes['net_amount']) if attributes['net_amount'].present?

    [gross - income - military, 0].max
  end

  def employee_id_for(attributes)
    code = identifier_for(attributes).to_s.strip.upcase
    return if code.blank?

    employees_by_id_code[code] || employees_by_identifier[code]
  end

  def identifier_for(attributes)
    attributes['id_code'].presence || attributes['identifier']
  end

  def employees_by_id_code
    @employees_by_id_code ||= Employee.pluck(:id, :id_code)
                                      .to_h { |id, code| [code.to_s.upcase, id] }
  end

  def employees_by_identifier
    @employees_by_identifier ||= Employee.where.not(identifier: [nil, ''])
                                         .pluck(:id, :identifier)
                                         .to_h { |id, code| [code.to_s.upcase, id] }
  end

  def department_id_for(value)
    return if value.blank?

    key = value.to_s.strip
    return key.to_i if key.match?(/\A\d+\z/) && Department.exists?(id: key.to_i)

    Department.find_by('LOWER(name) = ?', key.downcase)&.id
  end

  def normalize_type(value)
    TYPE_ALIASES[value.to_s.strip.downcase]
  end

  def skip(result, line_number, message)
    result.skipped += 1
    result.errors << I18n.t('historical_imports.errors.row', line: line_number, message: message)
  end
end
