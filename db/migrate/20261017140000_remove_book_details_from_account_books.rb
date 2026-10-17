# frozen_string_literal: true

class RemoveBookDetailsFromAccountBooks < ActiveRecord::Migration[8.0]
  def change
    remove_column :account_books, :book_name, :string
    remove_column :account_books, :book_number, :integer
    remove_column :account_books, :page_number, :integer
  end
end
