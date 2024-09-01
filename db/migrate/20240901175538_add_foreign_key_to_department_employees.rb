class AddForeignKeyToDepartmentEmployees < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :department_employees, :employees

    add_foreign_key :department_employees, :employees, column: :employee_id, on_delete: :cascade

    remove_foreign_key :department_employees, :departments
    add_foreign_key :department_employees, :departments, column: :department_id, on_delete: :cascade

    return unless foreign_key_exists?(:department_employees, :positions)

    remove_foreign_key :department_employees, :positions
    add_foreign_key :department_employees, :positions, column: :position_id, on_delete: :cascade
  end
end
