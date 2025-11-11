# frozen_string_literal: true

class CreateDepartments < ActiveRecord::Migration[7.1]
  def change
    create_table :departments do |t|
      t.string :department_name, null: false
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
