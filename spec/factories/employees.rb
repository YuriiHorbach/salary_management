FactoryBot.define do
  factory :employee do
    id_code { Faker::Number.unique.number(digits: 10) }
    first_name { Faker::Name.first_name }
    patronic_name { 'Testovich' }
    last_name { Faker::Name.last_name }
    total_salary { 1000 }
  end
end
