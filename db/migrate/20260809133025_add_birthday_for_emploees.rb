class AddBirthdayForEmploees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :birthday, :date
  end
end
