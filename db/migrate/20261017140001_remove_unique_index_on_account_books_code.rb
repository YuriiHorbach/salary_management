# frozen_string_literal: true

class RemoveUniqueIndexOnAccountBooksCode < ActiveRecord::Migration[8.0]
  def change
    remove_index :account_books, :code
  end
end
