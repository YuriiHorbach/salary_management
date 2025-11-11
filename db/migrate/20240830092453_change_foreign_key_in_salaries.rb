# frozen_string_literal: true

class ChangeForeignKeyInSalaries < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :salaries, :users, column: :employee_id
    add_foreign_key :salaries, :employees, column: :employee_id
  end
end
