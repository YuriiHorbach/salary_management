# frozen_string_literal: true

class FixDepartmentEmployeesForeignKey < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :department_employees, :users, column: :employee_id
    add_foreign_key :department_employees, :employees, column: :employee_id
  end
end
