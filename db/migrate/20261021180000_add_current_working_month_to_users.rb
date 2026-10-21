# frozen_string_literal: true

# Persists the month a user is currently working with. It is intentionally
# separate from the calendar month because payroll processing may lag behind or
# run ahead of the real date.
class AddCurrentWorkingMonthToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :current_working_month, :date
  end
end
