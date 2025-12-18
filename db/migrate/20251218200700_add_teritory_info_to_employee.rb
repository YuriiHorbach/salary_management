class AddTeritoryInfoToEmployee < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :territory_info, :string, null: false, default: ''
  end
end
