# frozen_string_literal: true

class Department < ApplicationRecord
  has_many :department_employees
  has_many :employees, through: :department_employees
  has_many :salaries

  def self.ransackable_attributes(*)
    %w[id name created_at updated_at]
  end

  def monthly_total(date = Date.current)
    salaries.where(period: date.to_date.beginning_of_month).sum(:amount_cents) / 100.0
  end
end
