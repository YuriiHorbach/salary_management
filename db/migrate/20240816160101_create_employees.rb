class CreateEmployees < ActiveRecord::Migration[7.1]
  def change
    create_table :employees do |t|
      t.integer :id_code, null: false
      t.string :first_name, null: false
      t.string :patronic_name
      t.string :last_name, null: false

      t.timestamps
    end
  end
end
