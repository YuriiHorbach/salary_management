# frozen_string_literal: true

class RemoveColumnFromDepartment < ActiveRecord::Migration[7.1]
  def change
    remove_column :departments, :employee_id, :string
  end
end
