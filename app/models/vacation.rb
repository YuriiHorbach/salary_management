class Vacation < ApplicationRecord
  belongs_to :employee

  monetize :vacation_amount_cents
end
