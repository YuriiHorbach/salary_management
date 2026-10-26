# db/seeds.rb
# УВАГА: ці seeds ВИДАЛЯЮТЬ дані й створюють ФЕЙКОВІ дані (імена, ІПН, суми).
# Вони дозволені лише для бази агента: docker compose --profile agent up -d --wait agent_db
unless ActiveRecord::Base.connection_db_config.database == 'salary_management_agent'
  warn 'Seeds пропущено: вони видаляють дані й дозволені лише для salary_management_agent.'
  return
end

srand(2026)                              # однакові дані при кожному запуску (дати відносно сьогодні)
ActiveJob::Base.queue_adapter = :inline  # податки зарплат рахуються одразу, а не у фоні

puts 'Ініціалізація налаштувань податків...'
TaxSetting.current

puts 'Очищення бази...'
DepartmentEmployee.destroy_all
Employee.destroy_all # разом зі зарплатами, відпустками, лікарняними та книгами працівників
AccountBook.destroy_all # довідник кодів без працівників
TerritorySign.destroy_all
Department.destroy_all

User.find_or_create_by!(email: 'agent@example.com') { |user| user.password = 'password123' }

puts 'Створення відділів...'
departments = ['Бухгалтерія', 'IT Відділ', 'Відділ кадрів', 'Логістика', 'Юридичний відділ',
               'Виробництво'].map do |name|
  Department.create!(name: name)
end

# Перша літера коду книги = бригада (так задумано в AccountBook). Назви вигадані.
brigade_books = {
  'Овочева' => %w[О11 О12],
  'Бурякова' => %w[Б111 Б112 Б211 Б212],
  'Чабанська' => %w[Ч1],
  'Насіннєва' => %w[Н1],
  'Тваринницька' => %w[Т00]
}

puts 'Створення бригад і довідника книг...'
territory_signs = brigade_books.keys.index_with { |name| TerritorySign.create!(name: name) }
brigade_books.each_value { |codes| codes.each { |code| AccountBook.create!(code: code) } }
books_by_code = AccountBook.all.index_by(&:code)

male_names = {
  first: %w[Олександр Андрій Іван Петро Микола Василь Сергій Олег Тарас Богдан Віктор Юрій],
  patronymic: %w[Олександрович Андрійович Іванович Петрович Миколайович Васильович Сергійович Олегович
                 Тарасович Богданович Вікторович Юрійович]
}
female_names = {
  first: %w[Олена Марія Наталія Ірина Оксана Юлія Анна Світлана Галина Людмила Катерина Вікторія],
  patronymic: %w[Олександрівна Андріївна Іванівна Петрівна Миколаївна Василівна Сергіївна Олегівна
                 Тарасівна Богданівна Вікторівна Юріївна]
}
last_names = %w[Шевченко Коваль Бондаренко Мельник Ткаченко Кравець Лисенко Мороз Савченко Гриценко
                Петренко Іваненко Мазур Романюк Поліщук Кузьменко Руденко Остапенко Захарченко Харченко]

today = Date.current
used_id_codes = Set.new
employees_count = 60

puts "Створення #{employees_count} працівників зі зарплатами, відпустками та лікарняними..."
employees_count.times do
  names = rand < 0.5 ? female_names : male_names
  birthday = today - rand((20 * 365)..(60 * 365)).days
  # РНОКПП: 5 цифр (дні від 31.12.1899) + 5 випадкових, щоб код збігався з датою народження.
  id_code = loop do
    candidate = format('%05d%05d', (birthday - Date.new(1899, 12, 31)).to_i, rand(100_000))
    break candidate if used_id_codes.add?(candidate)
  end

  brigade = brigade_books.keys.sample if rand < 0.7 # решта: «офісні» працівники без бригади й книги
  department = departments.sample

  employee = Employee.create!(
    id_code: id_code,
    first_name: names[:first].sample,
    last_name: last_names.sample,
    patronic_name: names[:patronymic].sample,
    children_count: [0, 0, 0, 1, 1, 2, 3].sample,
    disability_group: (rand < 0.06 ? [1, 2, 3].sample : nil),
    chaes: rand < 0.04,
    contract: rand < 0.15,
    territory_sign: territory_signs[brigade]
  )
  employee.update!(account_book: books_by_code.fetch(brigade_books[brigade].sample)) if brigade
  DepartmentEmployee.create!(employee: employee, department: department)

  next if rand < 0.05 # «новачки» без виплат, як у реальних звітах

  # Зарплата: щомісяця за останні 6 місяців, ~15% працівників із низькою ставкою (гілка ПСП в калькуляторі).
  base_uah = rand < 0.15 ? rand(3_000..4_500) : rand(6_000..40_000)
  6.times do |months_ago|
    paid_on = (today.beginning_of_month - months_ago.months).change(day: 10)
    next if paid_on > today

    Salary.create!(
      employee: employee,
      department: department,
      amount_cents: (base_uah * (0.95 + (rand * 0.1)) * 100).round,
      paid_on: paid_on.in_time_zone.change(hour: 12)
    )
  end

  if rand < 0.3
    Vacation.create!(
      employee: employee,
      vacation_amount_cents: rand(4_000..18_000) * 100,
      period: today.beginning_of_month - rand(1..5).months
    )
  end

  next unless rand < 0.25

  SickDay.create!(
    employee: employee,
    period: today.beginning_of_month - rand(1..5).months,
    pfu_amount_cents: rand(2_500..9_000) * 100,
    enterprise_amount_cents: rand(500..3_000) * 100
  )
end

puts "Готово! Відділів: #{Department.count}, працівників: #{Employee.count}, зарплат: #{Salary.count}, " \
     "відпусток: #{Vacation.count}, лікарняних: #{SickDay.count}."
puts 'Користувач для входу: agent@example.com / password123'
