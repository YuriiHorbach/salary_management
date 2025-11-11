# frozen_string_literal: true

class ChangeUserIdToEmployeeIdInSalaries < ActiveRecord::Migration[7.1]
  def change
    rename_column :salaries, :user_id, :employee_id
  end
end
