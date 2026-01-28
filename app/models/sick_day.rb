class SickDay < ApplicationRecord
  PDFO_RATE = 0.18
  MILITARY_RATE = 0.05

  belongs_to :employee

  attribute :period, :date

  monetize :pfu_amount_cents
  monetize :enterprise_amount_cents

  validates :period, presence: true
  validates :pfu_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :enterprise_amount, numericality: { greater_than_or_equal_to: 0 }

  def total_amount
    pfu_amount + enterprise_amount
  end

  def pdfo_amount
    (total_amount * PDFO_RATE).round(half_up: true)
  end

  def military_amount
    (total_amount * MILITARY_RATE).round(half_up: true)
  end
end
