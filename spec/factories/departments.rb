# frozen_string_literal: true

FactoryBot.define do
  factory :department do
    name { Faker::Commerce.department }
  end
end
