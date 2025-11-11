# frozen_string_literal: true

class ChangeForeignKeyInAccountBooks < ActiveRecord::Migration[7.1]
  def change
    rename_column :account_books, :user_id, :employee_id
    remove_foreign_key :account_books, :users, column: :employee_id
    add_foreign_key :account_books, :employees, column: :employee_id
  end
end
