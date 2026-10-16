class AddBookNumberAndPageToAccountBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :account_books, :book_number, :integer
    add_column :account_books, :page_number, :integer
  end
end
