class AddBookNumberAndBookNamePageToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :book_number, :integer
    add_column :employees, :book_name_page, :string
  end
end
