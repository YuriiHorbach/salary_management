class ChangeUserIdToEmployeeIdInDepartment < ActiveRecord::Migration[7.1]
  def change
    rename_column :departments, :user_id, :employee_id
  end
end
