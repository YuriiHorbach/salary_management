# frozen_string_literal: true

class AddDepartmentToSalaries < ActiveRecord::Migration[7.1]
  def change
    add_column :salaries, :department_id, :bigint
    add_index :salaries, :department_id
    add_foreign_key :salaries, :departments
  end
end
