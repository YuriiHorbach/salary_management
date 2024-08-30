class AddPositionToSalaries < ActiveRecord::Migration[7.1]
  def change
    add_column :salaries, :position_id, :bigint
    add_foreign_key :salaries, :positions
  end
end
