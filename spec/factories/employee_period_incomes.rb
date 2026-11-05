# frozen_string_literal: true

FactoryBot.define do
  factory :employee_period_income do
    association :employee

    period { Date.current.beginning_of_month }
    income_type { 'salary' }
    gross_cents { 0 }
    income_tax_cents { 0 }
    military_tax_cents { 0 }
    net_amount_cents { 0 }
  end
end
