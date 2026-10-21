# frozen_string_literal: true

# Salary paid to an employee for a month.
#
# An employee may have several salaries in the same period, but only one per
# department (when no position is selected) or per position. Taxes are
# aggregated by +Incomes::PeriodRecalculator+, not by this record alone.
class Salary < ApplicationRecord
  belongs_to :employee
  belongs_to :department, optional: true
  belongs_to :position, optional: true

  before_validation :derive_period_from_paid_on
  before_validation :derive_paid_on_from_period
  before_validation :normalize_period
  before_validation :sync_paid_on_with_period, if: :period_changed_on_persisted_record?
  before_validation :derive_department_from_position

  monetize :amount_cents, as: :amount
  validates :amount_cents, presence: true
  validates :period, presence: true
  validate :period_unique_within_scope
  validate :position_belongs_to_department
  validate :position_assigned_to_employee
  validates :income_tax_cents, :military_tax_cents, :net_amount_cents,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  monetize :income_tax_cents, as: :income_tax, allow_nil: true
  monetize :military_tax_cents, as: :military_tax, allow_nil: true
  monetize :net_amount_cents, as: :net_amount, allow_nil: true

  after_destroy :refresh_period_income
  after_save :refresh_period_income
  after_commit :enqueue_tax_calculation, on: %i[create update]

  scope :by_month, lambda { |month = nil|
    month.present? ? where('EXTRACT(MONTH FROM paid_on) = ?', month.to_i) : all
  }

  scope :by_year, lambda { |year = nil|
    year.present? ? where('EXTRACT(YEAR FROM paid_on) = ?', year.to_i) : all
  }

  scope :by_department, lambda { |department = nil|
    department.present? ? where('department_id = ?', department.to_i) : all
  }

  def self.ransackable_attributes(*)
    %w[amount_cents created_at department_id employee_id id paid_on period position_id updated_at]
  end

  def self.ransackable_associations(*)
    %w[department employee position]
  end

  def self.ransackable_scopes(*)
    %i[by_month by_year by_department]
  end

  # The standalone form submits the month input as "YYYY-MM".
  def period=(value)
    value = Date.strptime(value, '%Y-%m') if value.is_a?(String) && /\A\d{4}-\d{2}\z/.match?(value)
    super
  end

  def month
    period&.strftime('%Y-%m')
  end

  def year
    period&.year
  end

  def self.monthly_sum_for_employee(employee_id)
    sums = where(employee_id: employee_id)
           .group('EXTRACT(YEAR FROM paid_on)', 'EXTRACT(MONTH FROM paid_on)')
           .sum(:amount_cents)

    sums.transform_values { |value| value / 100.0 }
  end

  def enqueue_tax_calculation
    TaxCalculationJob.perform_later(id)
  end

  private

  def derive_period_from_paid_on
    self.period ||= paid_on&.beginning_of_month
  end

  def derive_paid_on_from_period
    self.paid_on ||= period
  end

  def normalize_period
    self.period = period.beginning_of_month if period.present?
  end

  def period_changed_on_persisted_record?
    persisted? && will_save_change_to_period?
  end

  def sync_paid_on_with_period
    self.paid_on = period
  end

  def derive_department_from_position
    self.department_id ||= position&.department_id
  end

  def period_unique_within_scope
    return if employee_id.blank? || period.blank?

    duplicates = self.class.where(employee_id: employee_id, period: period)
    duplicates = duplicates.where.not(id: id) if persisted?

    duplicates =
      if position_id.present?
        duplicates.where(position_id: position_id)
      else
        duplicates.where(position_id: nil, department_id: department_id)
      end

    return unless duplicates.exists?

    errors.add(:period, 'за цей період уже додано зарплату для цієї посади/підрозділу')
  end

  def position_belongs_to_department
    return if position.blank? || department_id.blank?
    return if position.department_id == department_id

    errors.add(:position, 'належить іншому підрозділу')
  end

  def position_assigned_to_employee
    return if position.blank? || employee_id.blank? || department_id.blank?
    return if DepartmentEmployee.exists?(employee_id: employee_id, department_id: department_id,
                                         position_id: position_id)

    errors.add(:position, 'не призначена цьому працівнику')
  end

  def refresh_period_income
    periods = [period]
    periods << period_before_last_save if saved_change_to_period?

    periods.compact.uniq.each do |changed_period|
      Incomes::PeriodRecalculator.call(employee: employee, period: changed_period, income_type: 'salary')
    end
  end

  def update_employee_total_salary
    employee.update(total_salary: employee.salaries.sum(:amount_cents) / 100.0)
  end
end
