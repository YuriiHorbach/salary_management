# db/seeds.rb
require 'faker'

puts "Очищення старої бази..."
# Спочатку очищаємо таблиці зв'язків, щоб не було помилок Foreign Key
DepartmentEmployee.destroy_all if defined?(DepartmentEmployee)
Employee.destroy_all
Department.destroy_all

puts "Створення відділів..."
departments = [
  Department.create!(name: "Бухгалтерія"),
  Department.create!(name: "IT Відділ"),
  Department.create!(name: "Відділ кадрів"),
  Department.create!(name: "Логістика"),
  Department.create!(name: "Юридичний відділ")
]

puts "Створення 10 працівників..."
10.times do
  employee = Employee.create!(
    id_code: Faker::Number.number(digits: 10),
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    patronic_name: "Іванович",
    children_count: rand(0..3),
    disability_group: nil,
    chaes: false,
    contract: [true, false].sample,
    birthday: Faker::Date.birthday(min_age: 20, max_age: 60)
  )

  # Прив'язуємо працівника до одного випадкового відділу
  DepartmentEmployee.create!(
    employee: employee,
    department: departments.sample
  )
end

puts "Готово! Створено відділи та 10 працівників."
