# frozen_string_literal: true

class Position < ApplicationRecord
  belongs_to :department
  has_many :department_employees, dependent: :destroy
  has_many :employees, through: :department_employees

  validates :position_name, presence: true

  def self.ransackable_attributes(*)
    %w[id position_name department_id created_at updated_at]
  end
end
