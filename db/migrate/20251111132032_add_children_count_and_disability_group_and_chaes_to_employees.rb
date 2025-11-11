# frozen_string_literal: true

class AddChildrenCountAndDisabilityGroupAndChaesToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :children_count, :integer
    add_column :employees, :disability_group, :integer
    add_column :employees, :chaes, :boolean
  end
end
