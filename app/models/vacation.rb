class Vacation < ApplicationRecord
  PDFO_RATE = 0.18
  MILITARY_RATE = 0.05

  belongs_to :employee

  attribute :period, :date

  monetize :vacation_amount_cents

  validates :period, presence: true
  validates :vacation_amount, numericality: { greater_than_or_equal_to: 0 }

  def self.ransackable_attributes(auth_object = nil)
    %w[period vacation_amount_cents income_tax_cents military_tax_cents net_amount_cents created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    ['employee']
  end

  def pdfo_amount
    (vacation_amount * PDFO_RATE).round(half_up: true)
  end

  def military_amount
    (vacation_amount * MILITARY_RATE).round(half_up: true)
  end

  # Returns the total vacation amount as a Money object.
  # This method is used in tests to verify the stored amount.
  def total_amount
    vacation_amount
  end
end
