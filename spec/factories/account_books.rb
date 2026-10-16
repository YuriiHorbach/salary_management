# frozen_string_literal: true

FactoryBot.define do
  factory :account_book do
    association :employee
    book_name { '61-11' }
  end
end
