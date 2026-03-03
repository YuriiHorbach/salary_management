# frozen_string_literal: true

FactoryBot.define do
  factory :sick_day do
    association :employee
    pfu_amount { 100_050 }
    enterprise_amount { 50_050 }
    period { '2026-01' }
  end
end
