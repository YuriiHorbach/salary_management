# frozen_string_literal: true

FactoryBot.define do
  factory :employee do
    id_code { Faker::Number.unique.number(digits: 10).to_s }
    first_name { Faker::Name.first_name }
    patronic_name { 'Testovich' }
    last_name { Faker::Name.last_name }
    contract { false }
  end
end
