# frozen_string_literal: true

class AddIdentifierToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :identifier, :string
    add_index :employees, :identifier
  end
end
