FactoryBot.define do
  factory :sick_leave do
    association :employee
    pfu_amount { 100000 }        # Значення за замовчуванням
    enterprise_amount { 50000 }
    period { "2026-01" }
  end
end