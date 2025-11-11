# frozen_string_literal: true

class RenameColumnDepartmentName < ActiveRecord::Migration[7.1]
  def change
    rename_column :departments, :department_name, :name
  end
end
