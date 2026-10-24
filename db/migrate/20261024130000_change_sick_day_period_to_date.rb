# frozen_string_literal: true

class ChangeSickDayPeriodToDate < ActiveRecord::Migration[8.0]
  def up
    change_column :sick_days, :period, :date, using: 'period::date'
  end

  def down
    change_column :sick_days, :period, :string, using: 'period::text'
  end
end
