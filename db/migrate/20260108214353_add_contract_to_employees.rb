class AddContractToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :contract, :boolean, default: false
  end
end
