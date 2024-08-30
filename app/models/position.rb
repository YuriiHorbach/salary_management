class Position < ApplicationRecord
  belongs_to :department, optional: true
  has_many :salaries
end
