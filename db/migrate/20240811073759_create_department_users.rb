# frozen_string_literal: true

class CreateDepartmentUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :department_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end
  end
end
