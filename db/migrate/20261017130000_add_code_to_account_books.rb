# frozen_string_literal: true

class AddCodeToAccountBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :account_books, :code, :string
    add_index :account_books, :code, unique: true
    change_column_null :account_books, :employee_id, true
  end
end
