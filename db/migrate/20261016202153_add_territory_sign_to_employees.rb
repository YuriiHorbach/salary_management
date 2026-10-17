class AddTerritorySignToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_reference :employees, :territory_sign, null: true, foreign_key: true
  end
end
