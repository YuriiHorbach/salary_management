# frozen_string_literal: true

class EmployeesController < ApplicationController
  SEARCH_KEYS = %i[
    id_code_cont last_name_cont first_name_cont patronic_name_cont
    territory_info_cont children_count_gt disability_group_eq
    chaes_true contract_true s
  ].freeze
  CHECKBOX_FILTER_KEYS = %w[chaes_true contract_true].freeze
  DEFAULT_EMPLOYEE_SORT = 'last_name asc'
  EMPLOYEES_PER_PAGE = 15
  SALARIES_PER_PAGE = 15
  VACATIONS_PER_PAGE = 15

  before_action :authenticate_user!
  before_action :set_employee, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[new edit create update]

  def index
    search_params = employee_search_params

    # Extract name params for case-insensitive search. PostgreSQL C collation
    # does not fold Cyrillic in SQL LIKE/ILIKE/LOWER, so we filter by field in Ruby
    # via search_by_field_ci (pluck ids + field, downcase-compare, query by ids).
    # Applied to the base scope before Ransack to avoid DISTINCT/ORDER BY conflicts.
    name_filters = {}
    %w[last_name first_name patronic_name].each do |field|
      key = "#{field}_cont"
      if search_params[key].present?
        name_filters[field] = search_params.delete(key)
      end
    end

    base_scope = Employee
    name_filters.each do |field, term|
      base_scope = base_scope.search_by_field_ci(field, term)
    end

    @q = base_scope.ransack(search_params)
    @q.sorts = [DEFAULT_EMPLOYEE_SORT] if @q.sorts.empty?
    @pagy, @employees = pagy(:offset, @q.result(distinct: true), limit: EMPLOYEES_PER_PAGE)
  end

  def show
    @employee = Employee.find_by(id: params[:id])
    return redirect_to employees_path, alert: t('flash.employees.not_found') if @employee.nil?

    @permitted_params = params.permit(:year, :month, :direction, :sort, q: {})

    @salary_amount_uah = params.dig(:salary_q, :amount_cents_eq).to_s.strip

    # used salary_q from params
    @salary_q = @employee.salaries.ransack(sanitized_salary_search_params, search_key: :salary_q)
    salary_scope = @salary_q.result
    @pagy_salaries, salary_records = pagy(:offset, salary_scope.includes(:department),
                                          limit: SALARIES_PER_PAGE, page_key: 'salaries_page')
    @employee_salaries = salary_records.group_by(&:department)

    @departments = Department.all

    prepare_monthly_totals(salary_scope)

    @vacation_q = @employee.vacations.ransack(params[:vacation_q], search_key: :vacation_q)
    @pagy_vacations, @vacations = pagy(:offset, @vacation_q.result.order(period: :desc),
                                       limit: VACATIONS_PER_PAGE, page_key: 'vacations_page')

    @sick_days_summaries = @employee.addition_income_summaries(@employee.sick_days)
  end

  def new
    @employee = Employee.new
  end

  def create
    @employee = Employee.new(employee_params)

    if @employee.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: t('flash.employees.created') }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @employee.update(employee_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to employees_path, notice: t('flash.employees.updated') }
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @employee.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to employees_path, notice: t('flash.employees.deleted') }
    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:id])
  end

  def load_form_collections
    @account_books = AccountBook.order(:code)
    @territory_signs = TerritorySign.ordered
  end

  # Unchecked checkboxes still submit "0" via Rails' hidden field. Passing that
  # to Ransack turns it into `chaes != TRUE`, which also drops NULL values
  # (imported employees have chaes = NULL). Treat "0" as "no filter" instead.
  def employee_search_params
    return {} if params[:q].blank?

    params[:q].permit(*SEARCH_KEYS).to_h.tap do |search|
      CHECKBOX_FILTER_KEYS.each { |key| search.delete(key) if search[key] == '0' }
      search['id_code_cont'] = search['id_code_cont'].to_s.strip.upcase if search['id_code_cont'].present?
    end
  end

  def employee_params
    params.require(:employee).permit(:first_name,
                                     :last_name,
                                     :patronic_name,
                                     :id_code,
                                     :territory_sign_id,
                                     :chaes,
                                     :contract,
                                     :disability_group,
                                     :children_count,
                                     :account_book_id,
                                     :page_number)
  end

  def sanitized_salary_search_params
    return {} unless params[:salary_q].present?

    permitted = params[:salary_q].permit(:amount_cents_eq, :by_year, :department_id_eq)

    permitted.to_h.tap do |hash|
      if hash[:amount_cents_eq].present?
        raw = hash[:amount_cents_eq].to_s.strip
        hash[:amount_cents_eq] = parse_amount_to_cents(raw)
      end
    end.compact
  end

  def parse_amount_to_cents(raw)
    return nil if raw.blank?

    normalized = raw.gsub(',', '.').gsub(' ', '')

    cents = (normalized.to_f * 100).round

    cents if cents.positive?
  end

  def prepare_monthly_totals(scope)
    grouped = scope.group_by { |salary| salary.paid_on.strftime('%Y-%m') }
    @monthly_totals = grouped.transform_values { |salaries| salaries.sum(&:amount_cents) / 100.0 }

    if params[:month].present?
      month_param = params[:month].rjust(2, '0')
      @monthly_totals.select! { |m, _| m.split('-').last == month_param }
    end

    @monthly_totals.select! { |m, _| m.split('-').first == params[:year] } if params[:year].present?
  end
end
