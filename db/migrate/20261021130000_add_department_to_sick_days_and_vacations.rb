# frozen_string_literal: true

class AddDepartmentToSickDaysAndVacations < ActiveRecord::Migration[8.0]
  def change
    add_reference :sick_days, :department, foreign_key: true, null: true
    add_reference :vacations, :department, foreign_key: true, null: true
  end
end
