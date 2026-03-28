# frozen_string_literal: true

FactoryBot.define do
  factory :vacation do
    association :employee
    period { Date.today }
    vacation_amount { 100 }
    income_tax_cents { 0 }
    military_tax_cents { 0 }
    net_amount_cents { 0 }
  end
end
