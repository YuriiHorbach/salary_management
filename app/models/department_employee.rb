# frozen_string_literal: true

class DepartmentEmployee < ApplicationRecord
  belongs_to :employee
  belongs_to :department
  belongs_to :position, optional: true

  validates :employee_id,
            uniqueness: {
              scope: %i[department_id position_id],
              message: 'вже має цю посаду в цьому підрозділі'
            }
end
