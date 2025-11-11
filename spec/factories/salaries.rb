# frozen_string_literal: true

FactoryBot.define do
  factory :salary do
    association :employee
    association :department
    amount { 1000 }
    paid_on { Date.today }
  end
end
