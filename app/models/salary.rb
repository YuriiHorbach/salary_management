class Salary < ApplicationRecord
  belongs_to :employee
  belongs_to :position
end
