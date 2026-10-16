# frozen_string_literal: true

class TerritorySign < ApplicationRecord
  has_many :employees, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  def to_s
    name
  end
end
