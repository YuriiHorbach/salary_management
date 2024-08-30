class MakePositionIdNotNullableInSalaries < ActiveRecord::Migration[7.1]
  def change
    change_column_null :salaries, :position_id, false
  end
end
