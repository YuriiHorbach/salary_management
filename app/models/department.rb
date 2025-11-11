# frozen_string_literal: true

class Department < ApplicationRecord
  has_many :department_employees
  has_many :employees, through: :department_employees
  has_many :salaries

  def self.ransackable_attributes(*)
    %w[id name created_at updated_at]
  end
end
