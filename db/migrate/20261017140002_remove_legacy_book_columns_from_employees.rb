# frozen_string_literal: true

class RemoveLegacyBookColumnsFromEmployees < ActiveRecord::Migration[8.0]
  def change
    remove_column :employees, :book_number, :integer
    remove_column :employees, :book_name_page, :string
  end
end
