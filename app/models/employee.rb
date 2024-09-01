class Employee < ApplicationRecord
  has_many :department_employees
  has_many :departments, through: :department_employees
  has_many :positions, through: :department_employees
  has_many :salaries

  validates :id_code, presence: true, length: { minimum: 10, maximum: 10 }, uniqueness: true
  validates :first_name, presence: true
  validates :patronic_name, presence: true
  validates :last_name, presence: true
end
