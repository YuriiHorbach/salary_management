class RemoveTotalSalaryFromEmployees < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:employees, :total_salary)
      remove_column :employees, :total_salary, :decimal
    end
  end
end
