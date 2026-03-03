class CreateSickDays < ActiveRecord::Migration[8.0]
  def change
    create_table :sick_days do |t|
      t.references :employee, null: false, foreign_key: true
      t.integer :pfu_amount, default: 0, null: false
      t.integer :enterprise_amount, default: 0, null: false
      t.string :period, null: false

      t.timestamps
    end
  end
end
