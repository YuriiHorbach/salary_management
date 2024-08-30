class Salary < ApplicationRecord
  belongs_to :employee
  belongs_to :department
  belongs_to :position, optional: true
end
