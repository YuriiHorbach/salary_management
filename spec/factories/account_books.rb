# frozen_string_literal: true

FactoryBot.define do
  factory :account_book do
    sequence(:code) { |n| "Б#{n}" }

    # Convenience for specs that used to create the book together with its
    # owner. The catalog row is created first and then assigned to the employee.
    transient do
      employee { nil }
    end

    after(:create) do |book, evaluator|
      evaluator.employee&.update!(account_book: book)
    end
  end
end
