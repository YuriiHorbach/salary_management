# frozen_string_literal: true

class Employee < ApplicationRecord
  has_many :department_employees
  has_many :departments, through: :department_employees
  has_many :positions, through: :department_employees
  has_many :salaries, dependent: :destroy

  validates :id_code, presence: true, length: { minimum: 10, maximum: 10 }, uniqueness: true
  validates :first_name, presence: true
  validates :patronic_name, presence: true
  validates :last_name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at first_name id id_code id_value last_name patronic_name updated_at children_count disability_group chaes territory_info]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[department_employees departments positions salaries]
  end

  def total_salary
    salaries.sum(:amount)
  end
end
