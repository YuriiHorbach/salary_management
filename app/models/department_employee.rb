# frozen_string_literal: true

class DepartmentEmployee < ApplicationRecord
  belongs_to :employee
  belongs_to :department
end
