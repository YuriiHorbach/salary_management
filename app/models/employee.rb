# frozen_string_literal: true

class Employee < ApplicationRecord
  before_validation :set_birthdate_from_id_code, if: :id_code_changed?

  has_many :department_employees
  has_many :departments, through: :department_employees
  has_many :positions, through: :department_employees
  has_many :salaries, dependent: :destroy
  has_many :sick_days, class_name: 'SickDay', dependent: :destroy
  has_many :vacations, dependent: :destroy # Added association for vacations
  has_one :account_book, dependent: :destroy
  belongs_to :territory_sign, optional: true
  accepts_nested_attributes_for :account_book, reject_if: ->(attributes) { attributes['code'].blank? }

  validates :id_code, presence: true, length: { minimum: 10, maximum: 10 }, uniqueness: true
  validates :first_name, presence: true
  validates :patronic_name, presence: true
  validates :last_name, presence: true

  after_save :recalculate_taxes_if_needed
  after_save :set_book_identifier

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
    "#{first_name} #{last_name}"
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
    return if id_code.blank?

    id_code.to_s[0..4].to_i
    Date.new(1899, 12, 31)
  end
end
