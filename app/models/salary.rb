# frozen_string_literal: true

class Salary < ApplicationRecord
  belongs_to :employee
  belongs_to :department, optional: true

  validates :amount, presence: true

  # Monetize tax-related cents columns so we can work with Money objects in app code
  monetize :income_tax_cents, as: :income_tax, allow_nil: true
  monetize :military_tax_cents, as: :military_tax, allow_nil: true
  monetize :net_amount_cents, as: :net_amount, allow_nil: true

  after_commit :enqueue_tax_calculation, on: [:create, :update]

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
    %w[amount created_at department_id employee_id id paid_on updated_at]
  end

  def self.ransackable_associations(*)
    %w[department employee]
  end

  def self.ransackable_scopes(*)
    %i[by_month by_year by_department]
  end

  def month
    paid_on&.strftime('%Y-%m')
  end

  def year
    paid_on&.year
  end

  def self.monthly_sum_for_employee(employee_id)
    where(employee_id: employee_id)
      .group('EXTRACT(YEAR FROM paid_on)', 'EXTRACT(MONTH FROM paid_on)')
      .sum(:amount)
  end

  def enqueue_tax_calculation
    TaxCalculationJob.perform_later(id)
  end

  private

  def update_employee_total_salary
    employee.update(total_salary: employee.salaries.sum(:amount))
  end
end
