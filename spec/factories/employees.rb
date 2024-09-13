FactoryBot.define do
  factory :employee do
    id_code { 1_111_111_111 }
    first_name { Faker::Name.first_name }
    patronic_name { 'Testovich' }
    last_name { Faker::Name.last_name }
    total_salary { 1000 }
  end
end
