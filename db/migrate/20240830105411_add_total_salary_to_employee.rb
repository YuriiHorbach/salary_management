# frozen_string_literal: true

class AddTotalSalaryToEmployee < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :total_salary, :decimal, default: 0.0
  end
end
