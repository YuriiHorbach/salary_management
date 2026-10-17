# frozen_string_literal: true

FactoryBot.define do
  factory :account_book do
    sequence(:code) { |n| "Б#{n}" }
    employee
  end
end
