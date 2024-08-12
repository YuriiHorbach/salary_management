class Department < ApplicationRecord
  has_many :department_users
  has_many :users, through: :department_users
end
