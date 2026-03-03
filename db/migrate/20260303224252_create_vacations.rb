class CreateVacations < ActiveRecord::Migration[8.0]
  def change
    create_table :vacations do |t|
      t.references :employee, null: false, foreign_key: true
      t.integer :vacation_amount_cents, default: 0, null: false
      t.date :period, null: false

      t.timestamps
    end
  end
end
