# frozen_string_literal: true

FactoryBot.define do
  factory :position do
    association :department
    position_name { Faker::Job.title }
  end
end
