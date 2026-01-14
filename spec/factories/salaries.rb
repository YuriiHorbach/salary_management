# frozen_string_literal: true

FactoryBot.define do
  factory :salary do
    association :employee
    association :department

    amount_cents { 4000 }
    paid_on { Date.today }

    income_tax_cents { 0 }
    military_tax_cents { 0 }
    net_amount_cents { 0 }
  end
end
