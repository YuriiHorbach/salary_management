# frozen_string_literal: true

class DepartmentEmployee < ApplicationRecord
  belongs_to :employee
  belongs_to :department

  validates :employee_id, uniqueness: { scope: :department_id, message:'employee alredy exists in this department'}
end
