class ChangeIdCodeToBigIntInEmployees < ActiveRecord::Migration[7.1]
  def change
    change_column :employees, :id_code, :bigint
  end
end
