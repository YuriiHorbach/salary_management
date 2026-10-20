# frozen_string_literal: true

class ChangeIdCodeToStringInEmployees < ActiveRecord::Migration[8.0]
  def up
    change_column :employees, :id_code, :string, null: false, using: 'id_code::text'
    add_index :employees, :id_code, unique: true unless index_exists?(:employees, :id_code)
  end

  def down
    remove_index :employees, :id_code if index_exists?(:employees, :id_code)
    change_column :employees, :id_code, :bigint, null: false, using: 'id_code::bigint'
  end
end
