# frozen_string_literal: true

# Employee master record with tax settings and associations to income records.
#
# Tax-affecting attribute changes trigger +RecalculateEmployeeTaxes+ for the
# current month only. Period aggregates are removed together with the employee.
class Employee < ApplicationRecord
  # 10-digit RNOKPP, 9-digit ID-card number, or a 2-letter + 6-digit passport book number.
  ID_CODE_PATTERNS = [
    /\A\d{9,10}\z/,
    /\A[А-ЯҐІЇЄA-Z]{2}\d{6}\z/
  ].freeze

  before_validation :normalize_id_code
  before_validation :set_birthdate_from_id_code, if: :id_code_changed?

  has_many :department_employees
  has_many :departments, through: :department_employees
  has_many :positions, through: :department_employees
  has_many :salaries, dependent: :destroy
  has_many :employee_period_incomes, dependent: :destroy
  has_many :sick_days, class_name: 'SickDay', dependent: :destroy
  has_many :vacations, dependent: :destroy # Added association for vacations
  has_one :account_book, dependent: :destroy
  belongs_to :territory_sign, optional: true
  accepts_nested_attributes_for :account_book, reject_if: ->(attributes) { attributes['code'].blank? }

  validates :id_code, presence: true, uniqueness: { case_sensitive: false }
  validate :id_code_format
  validates :first_name, presence: true
  validates :patronic_name, presence: true
  validates :last_name, presence: true

  after_save :recalculate_taxes_if_needed
  after_save :set_book_identifier

  # PostgreSQL uses the C collation here, so ILIKE/LOWER do not fold Cyrillic.
  # Match case-insensitively in Ruby and keep returning a relation for chaining.
  scope :search_by_id_code_or_name, lambda { |term|
    next all if term.blank?

    normalized = term.to_s.strip.downcase
    ids = pluck(:id, :id_code, :last_name, :first_name, :patronic_name).filter_map do |id, *values|
      id if values.any? { |value| value.to_s.downcase.include?(normalized) }
    end

    where(id: ids)
  }

  def self.ransackable_attributes(_auth_object = nil)
    # Ensure amount_cents is listed here to allow searching through associations
    %w[created_at first_name id id_code id_value last_name patronic_name updated_at children_count disability_group
       chaes contract territory_info amount_cents identifier]
  end

  def self.ransackable_associations(_auth_object = nil)
    # Ensure salaries association is listed for Ransack to traverse
    %w[department_employees departments positions salaries sick_days vacations]
  end

  def book_identifier
    account_book&.code
  end

  def total_salary
    salaries.sum(:amount_cents) / 100.0
  end

  # Gross salary amounts grouped by department and position.
  # Keys are +[department_id, position_id]+; either value may be +nil+.
  # This is a salary-only breakdown; taxes remain aggregated per period by
  # +EmployeePeriodIncome+ and are not allocated to positions here.
  #
  # @param period [Date, String, nil] optional month to restrict the result
  # @return [Hash{Array(Integer, Integer, nil) => Integer}] amounts in cents
  def salary_totals_by_department_and_position(period: nil)
    scope = salaries
    scope = scope.where(period: period) if period
    scope.group(:department_id, :position_id).sum(:amount_cents)
  end

  def addition_income_summaries(income)
    income.group_by(&:period).transform_values do |days|
      first_item = days.first

      summary = {
        pdfo: days.map(&:pdfo_amount).sum,
        military: days.map(&:military_amount).sum
      }

      summary[:total] = days.map(&:total_amount).sum if first_item.respond_to?(:total_amount)

      summary
    end
  end

  def sick_days_summaries
    sick_days.group_by(&:period).transform_values do |days|
      {
        pfu: days.map(&:pfu_amount).sum,
        enterprise: days.map(&:enterprise_amount).sum,
        total: days.map(&:total_amount).sum
      }
    end
  end

  def last_salary_display
    salaries.last&.amount || "+ Add"
  end

  def full_name
    [last_name, first_name, patronic_name].compact_blank.join(' ')
  end

  def full_name_with_id_code
    "#{id_code} — #{last_name} #{first_name} #{patronic_name}"
  end

  private

  def set_book_identifier
    computed = book_identifier
    return if computed.nil?
    return if identifier == computed

    update_column(:identifier, computed)
  end

  def recalculate_taxes_if_needed
    return unless tax_affecting_attributes_changed?

    RecalculateEmployeeTaxes.call(self)
  end

  def tax_affecting_attributes_changed?
    saved_change_to_children_count? ||
      saved_change_to_disability_group? ||
      saved_change_to_chaes? ||
      saved_change_to_contract?
  end

  def set_birthdate_from_id_code
    return unless id_code.to_s.match?(/\A\d{10}\z/)

    # RNOKPP starts with the number of days since 31.12.1899.
    self.birthday = Date.new(1899, 12, 31) + id_code.to_s.first(5).to_i
  end

  def normalize_id_code
    self.id_code = id_code.to_s.strip.upcase.presence
  end

  def id_code_format
    return if id_code.blank?
    return if ID_CODE_PATTERNS.any? { |pattern| id_code.match?(pattern) }

    errors.add(:id_code, :invalid_id_code)
  end
end
