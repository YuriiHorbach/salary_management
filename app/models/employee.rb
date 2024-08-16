class Employee < ApplicationRecord
  has_many :department_employees
  has_many :departments, through: :department_employees

  has_many :salaries
end
