class AddPositionToDepartmentEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :department_employees, :position_id, :bigint
    add_index :department_employees, :position_id
    add_foreign_key :department_employees, :positions
  end
end
