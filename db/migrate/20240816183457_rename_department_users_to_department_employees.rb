class RenameDepartmentUsersToDepartmentEmployees < ActiveRecord::Migration[7.1]
  def change
    rename_table :department_users, :department_employees
  end
end
