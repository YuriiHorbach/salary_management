class ChangeUserToEmployeeInDepartmentUsers < ActiveRecord::Migration[7.1]
  def change
    rename_column :department_users, :user_id, :employee_id
  end
end
