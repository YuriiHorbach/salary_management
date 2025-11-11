# frozen_string_literal: true

class RemovePositionIdFromSalaries < ActiveRecord::Migration[7.1]
  def change
    remove_column :salaries, :position_id
  end
end
