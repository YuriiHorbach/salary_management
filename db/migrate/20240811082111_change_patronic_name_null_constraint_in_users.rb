class ChangePatronicNameNullConstraintInUsers < ActiveRecord::Migration[7.1]
  def change
    change_column_null :users, :patronic_name, true
  end
end
