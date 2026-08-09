class RemoveInvalidColumnFromEmployees < ActiveRecord::Migration[7.1]
  def change
    remove_column :employees, :"id_code;last_name;first_name;patronic_name;birthdate;territory_"
  end
end

