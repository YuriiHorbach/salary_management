class CreatePositions < ActiveRecord::Migration[7.1]
  def change
    create_table :positions do |t|
      t.string :position_name, null: false
      t.bigint :department_id, null: true
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :department_id
    end

    add_foreign_key :positions, :departments
  end
end
