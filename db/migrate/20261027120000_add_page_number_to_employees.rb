# frozen_string_literal: true

# Stores the user-defined page reference for an employee, for example "Б111-1".
# It is a free-form string because it combines a book/brigade prefix and a number.
class AddPageNumberToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :page_number, :string
  end
end
