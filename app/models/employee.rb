class Employee < ApplicationRecord
  has_many :department_employees
  has_many :departments, through: :department_employees
  has_many :positions, through: :department_employees
  has_many :salaries, dependent: :destroy

  validates :id_code, presence: true, length: { minimum: 10, maximum: 10 }, uniqueness: true
  validates :first_name, presence: true
  validates :patronic_name, presence: true
  validates :last_name, presence: true
  validates :total_salary, numericality: { greater_than_or_equal_to: 0 }
end
