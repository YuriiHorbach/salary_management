class Department < ApplicationRecord
  has_many :department_employees
  has_many :employees, through: :department_employees
end
