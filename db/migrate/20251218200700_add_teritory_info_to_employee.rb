class AddTeritoryInfoToEmployee < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :chaes, :boolean, null: false, default: false
    add_column :employees, :disability_group, :integer, null: false, default: 0
    add_column :employees, :children_count, :integer, null: false, default: 0
  end
end
