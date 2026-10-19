class RemoveInvalidColumnFromEmployees < ActiveRecord::Migration[7.1]
  # This column was created accidentally by a legacy CSV import and only exists
  # in those databases; skip it on a clean database.
  def change
    if column_exists?(:employees, :"id_code;last_name;first_name;patronic_name;birthdate;territory_")
      remove_column :employees, :"id_code;last_name;first_name;patronic_name;birthdate;territory_"
    end
  end
end

