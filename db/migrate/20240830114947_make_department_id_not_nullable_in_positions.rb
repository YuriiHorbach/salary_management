class MakeDepartmentIdNotNullableInPositions < ActiveRecord::Migration[7.1]
  def change
    change_column_null :positions, :department_id, false
  end
end
