# Task Specs Creation Guide

This guide documents how the specs for the recent search and department-count tasks were designed and implemented. It is intended as a repeatable checklist for future tasks in this project.

---

## 1. Test environment

All specs must run against the isolated AI agent database on port `5434`, never the developer database on `5433` or a local PostgreSQL instance on `5432`.

```bash
RAILS_ENV=test DB_HOST=localhost DB_PORT=5434 \
TEST_DB_NAME=salary_management_agent_test \
DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
bundle exec rspec
```

For a focused test run, append the file names or line numbers:

```bash
RAILS_ENV=test DB_HOST=localhost DB_PORT=5434 \
TEST_DB_NAME=salary_management_agent_test \
DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
bundle exec rspec spec/requests/employees_spec.rb
```

---

## 2. General workflow

1. **Read the requirement and locate the behavior.**
   - UI behavior belongs in a request spec.
   - Pure domain logic belongs in a model spec.
   - JavaScript/Turbo interactions belong in a system spec.

2. **Write the spec before the implementation.**
   - Run it and confirm it fails for the expected reason.
   - This proves the spec covers the new behavior.

3. **Use factories for test data.**
   - Override only the attributes relevant to the task.
   - Use explicit ID codes and names when asserting exact results.

4. **Run the focused specs.**
   - Fix implementation or spec errors until green.

5. **Run the full suite and RuboCop.**
   - Confirm no regressions.
   - Do not introduce new RuboCop offenses.

---

## 3. Task: employee counts on department pages

### Requirement

Show the number of employees in a department:

- on the departments list page, per department card;
- on the department details page, near the department name.

An employee with several positions must be counted only once.

### Model spec

File: `spec/models/department_spec.rb`

```ruby
describe '.employee_counts' do
  it 'returns the number of distinct employees for each department' do
    department = create(:department)
    other_department = create(:department)
    position = create(:position, department: department)
    employee = create(:employee)
    other_employee = create(:employee)

    create(:department_employee, employee: employee, department: department, position: position)
    create(:department_employee, employee: employee, department: department)
    create(:department_employee, employee: other_employee, department: other_department)

    expect(described_class.employee_counts).to include(
      department.id => 1,
      other_department.id => 1
    )
  end

  it 'omits departments without employees' do
    department = create(:department)

    expect(described_class.employee_counts).not_to have_key(department.id)
  end
end
```

### Request specs

File: `spec/requests/departments_spec.rb`

```ruby
context 'with employee counts' do
  it 'shows the number of employees for each department' do
    sign_in(user)
    department = create(:department)
    empty_department = create(:department)
    create_list(:department_employee, 2, department: department)

    get departments_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css("#department_#{department.id}_employee_count").text.strip).to eq('2')
    expect(doc.at_css("#department_#{empty_department.id}_employee_count").text.strip).to eq('0')
  end

  it 'does not count an employee twice when they have several positions' do
    sign_in(user)
    department = create(:department)
    position = create(:position, department: department)
    employee = create(:employee)
    create(:department_employee, employee: employee, department: department)
    create(:department_employee, employee: employee, department: department, position: position)

    get departments_path

    count = Nokogiri::HTML(response.body).at_css("#department_#{department.id}_employee_count")
    expect(count.text.strip).to eq('1')
  end
end
```

```ruby
it 'shows the number of employees in the department' do
  get department_path(department)

  count = Nokogiri::HTML(response.body).at_css('#department_employees_count')
  expect(count.text.strip).to eq('2')
end
```

---

## 4. Task: partial ID code search on the employees page

### Requirement

The user enters only part of an employee ID code and receives all matching employees.

Example: `99999` matches `9999999901`.

### Request spec

File: `spec/requests/employees_spec.rb`

```ruby
describe 'GET /employees id code search' do
  let!(:matching_employee) { create(:employee, id_code: '9999999901') }
  let!(:non_matching_employee) { create(:employee, id_code: '8888888802') }

  it 'finds employees by a partial id code' do
    get employees_path, params: { q: { id_code_cont: '99999' } }

    expect(response).to have_http_status(:ok)
    expect(assigns(:employees)).to include(matching_employee)
    expect(assigns(:employees)).not_to include(non_matching_employee)
  end

  it 'ignores surrounding whitespace in the id code fragment' do
    get employees_path, params: { q: { id_code_cont: '  99999  ' } }

    expect(assigns(:employees)).to include(matching_employee)
  end

  it 'finds passport-style id codes typed in lowercase' do
    passport_employee = create(:employee, id_code: 'АА123456')

    get employees_path, params: { q: { id_code_cont: 'аа12' } }

    expect(assigns(:employees)).to include(passport_employee)
  end
end
```

### Why `id_code_cont`

Ransack's `_cont` predicate generates a `LIKE '%value%'` query. The controller also normalizes the fragment:

```ruby
search['id_code_cont'] = search['id_code_cont'].to_s.strip.upcase if search['id_code_cont'].present?
```

This removes surrounding whitespace and makes lowercase passport-style input match the stored uppercase ID code.

---

## 5. Task: partial ID code search on the Add Employees page

### Requirement

The Add Employees page must also support partial ID code search and preserve table sorting while filtering.

### Request specs

File: `spec/requests/department_employees_spec.rb`

```ruby
it 'filters employees by a partial id code' do
  matching_employee = create(:employee, id_code: '7777777701')
  non_matching_employee = create(:employee, id_code: '6666666602')

  get new_department_employee_path(department_id: department.id, q: { id_code_cont: '77777' })

  employee_ids = Nokogiri::HTML(response.body)
                         .css('input[name="employee_ids[]"]')
                         .map { |checkbox| checkbox['value'] }

  expect(employee_ids).to include(matching_employee.id.to_s)
  expect(employee_ids).not_to include(non_matching_employee.id.to_s)
end

it 'finds passport-style id codes typed in lowercase' do
  passport_employee = create(:employee, id_code: 'ББ654321')

  get new_department_employee_path(department_id: department.id, q: { id_code_cont: 'бб65' })

  employee_ids = Nokogiri::HTML(response.body)
                         .css('input[name="employee_ids[]"]')
                         .map { |checkbox| checkbox['value'] }

  expect(employee_ids).to include(passport_employee.id.to_s)
end

it 'keeps sorting when filtering by a partial id code' do
  create(:employee, id_code: '5555555501')
  create(:employee, id_code: '5555555502')

  get new_department_employee_path(
    department_id: department.id,
    q: { id_code_cont: '55555', s: 'id_code desc' }
  )

  employee_codes = Nokogiri::HTML(response.body)
                           .css('tbody tr td:first-child')
                           .map { |cell| cell.text.strip }

  expect(employee_codes).to eq(%w[5555555502 5555555501])
end
```

### Controller detail

`DepartmentEmployeesController` must permit `:s` along with the search keys, otherwise Ransack sorting is lost when a filter is present:

```ruby
SEARCH_KEYS = %i[id_code_cont last_name_cont first_name_cont patronic_name_cont s].freeze
```

---

## 6. Task: partial ID code search on the sick day entry page

### Requirement

`GET /sick_day_entries/new` must filter the employee list when the user enters only part of an ID code.

This page uses the shared `Employee.search_by_id_code_or_name` scope. That scope already performs case-insensitive partial matching against the ID code and full name, so the production search logic is shared with the vacation entry page.

The search form submits to the full page (`data: { turbo_frame: "_top" }`) rather than replacing only the employee form. This guarantees the filtered results, the search term, and the result count are all refreshed together.

When a search term is present, matching employees are rendered as a visible, selectable radio list instead of a collapsed dropdown. This lets the user see exactly who matched and choose the right employee. With no search term, the normal dropdown of all employees is shown.

### Request specs

File: `spec/requests/sick_day_entries_spec.rb`

```ruby
it 'shows employees matching a partial id code as selectable options' do
  get new_sick_day_entry_path, params: { employee_search: '9876' }

  doc = Nokogiri::HTML(response.body)
  radio_values = doc.css('input[type="radio"][name="sick_day[employee_id]"]').map { |radio| radio['value'] }

  expect(radio_values).to eq([ivanenko.id.to_s])
  expect(doc.text).to include(ivanenko.full_name_with_id_code)
  expect(doc.text).not_to include(petrenko.full_name_with_id_code)
end

it 'shows a passport book id code match typed in lowercase' do
  passport_employee = create(:employee, id_code: 'АА123456', last_name: 'Шевченко',
                                        first_name: 'Тарас', patronic_name: 'Григорович')

  get new_sick_day_entry_path, params: { employee_search: 'аа12' }

  doc = Nokogiri::HTML(response.body)

  expect(doc.text).to include(passport_employee.full_name_with_id_code)
  expect(doc.text).not_to include(petrenko.full_name_with_id_code, ivanenko.full_name_with_id_code)
end

it 'ignores whitespace around a partial id code' do
  get new_sick_day_entry_path, params: { employee_search: '  9876  ' }

  doc = Nokogiri::HTML(response.body)

  expect(doc.text).to include(ivanenko.full_name_with_id_code)
  expect(doc.text).not_to include(petrenko.full_name_with_id_code)
end
```

### Result count and empty state

The page shows how many employees matched and displays an empty-state message when nothing matches:

```ruby
it 'shows how many employees matched the partial id code' do
  get new_sick_day_entry_path, params: { employee_search: '9876' }

  count = Nokogiri::HTML(response.body).at_css('#sick_day_employee_search_count')

  expect(count.text.strip).to eq('1')
end

it 'shows an empty state when no employee matches' do
  get new_sick_day_entry_path, params: { employee_search: '0000' }

  doc = Nokogiri::HTML(response.body)

  expect(doc.at_css('#sick_day_employee_search_count').text.strip).to eq('0')
  expect(doc.text).to include('Працівників за таким запитом не знайдено.')
end
```

### Failed-create regression spec

The search term must survive validation errors and keep the filtered employee list available:

```ruby
it 'keeps the partially filtered employee list after a failed create' do
  matching_employee = create(:employee, id_code: '9876543210')
  non_matching_employee = create(:employee, id_code: '1111111111')

  post sick_day_entries_path, params: {
    employee_search: '9876',
    sick_day: { employee_id: matching_employee.id, period: '', pfu_amount: '10.00' }
  }

  doc = Nokogiri::HTML(response.body)
  selected_radio = doc.at_css(
    "input[type='radio'][name='sick_day[employee_id]'][value='#{matching_employee.id}'][checked]"
  )
  expect(selected_radio).to be_present
  expect(doc.text).to include(matching_employee.full_name_with_id_code)
  expect(doc.text).not_to include(non_matching_employee.full_name_with_id_code)
end
```

---

## 7. Spec patterns used in this project

### Request specs

Use request specs for:

- search and filtering behavior;
- rendered content;
- controller parameter handling;
- redirects and status codes.

Example structure:

```ruby
RSpec.describe 'Employees', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'filters the collection' do
    get employees_path, params: { q: { id_code_cont: '1234' } }

    expect(response).to have_http_status(:ok)
  end
end
```

### Model specs

Use model specs for:

- scopes;
- query calculations;
- validations;
- domain methods.

Example:

```ruby
RSpec.describe Employee, type: :model do
  describe '.search_by_id_code_or_name' do
    it 'matches part of the id code' do
      employee = create(:employee, id_code: '1234567890')

      expect(described_class.search_by_id_code_or_name('4567')).to include(employee)
    end
  end
end
```

### System specs

Use system specs for flows that depend on:

- Turbo Frames or Turbo Streams;
- Stimulus controllers;
- JavaScript behavior;
- multi-step user interactions.

They are slower, so only add them when request specs cannot cover the behavior.

---

## 8. Asserting rendered HTML with Nokogiri

Prefer stable element identifiers and names over matching whole-page text.

```ruby
doc = Nokogiri::HTML(response.body)

select = doc.at_css('select[name="sick_day[employee_id]"]')
expect(select.text).to include(employee.last_name)

checkbox_ids = doc.css('input[name="employee_ids[]"]').map { |input| input['value'] }
expect(checkbox_ids).to include(employee.id.to_s)
```

Add explicit DOM IDs when a test needs to target a value reliably:

```erb
<span id="department_<%= department.id %>_employee_count">
  <%= employee_counts.fetch(department.id, 0) %>
</span>
```

---

## 9. Common pitfalls

### Duplicate ID codes

The `employee` factory uses Faker, but explicit ID codes in specs can collide with records created by outer `let!` blocks.

Use a distinct code in each example:

```ruby
create(:employee, id_code: '1111111111')
create(:employee, id_code: '9876543210')
```

### Case-sensitive database collation

PostgreSQL in this project may use a C collation where `LOWER`/`ILIKE` do not fold Cyrillic reliably. The shared Ruby-based `search_by_id_code_or_name` scope performs case-insensitive matching in Ruby for that reason.

### Turbo Frames

When a form is rendered inside a Turbo Frame, assert the correct frame and use the actual input names in the rendered HTML.

### Hidden search fields

The sick day form stores the search term in a hidden field so it survives form submission. When testing failed creates, send both `employee_search` and the invalid `sick_day` attributes.

### Sorting with filters

Ransack sort links submit `q[s]`. Any controller that whitelists search params must also permit `:s`, otherwise sorting disappears when a search filter is applied.

---

## 10. Verification checklist

- [ ] Focused request/model specs pass.
- [ ] Full suite passes.
- [ ] RuboCop reports no new offenses in changed files.
- [ ] Tests use the isolated agent database on port `5434`.
- [ ] No changes to `config/database.yml`.
- [ ] No database reset/drop commands were used.
- [ ] New behavior is covered by a spec that failed before the implementation.

---

## 11. Useful commands

Run the full suite:

```bash
RAILS_ENV=test DB_HOST=localhost DB_PORT=5434 \
TEST_DB_NAME=salary_management_agent_test \
DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
bundle exec rspec
```

Run a single spec file:

```bash
RAILS_ENV=test DB_HOST=localhost DB_PORT=5434 \
TEST_DB_NAME=salary_management_agent_test \
DB_USERNAME=sm_agent DB_PASSWORD=agent_password \
bundle exec rspec spec/requests/sick_day_entries_spec.rb
```

Run RuboCop on changed Ruby files:

```bash
bundle exec rubocop app/controllers/employees_controller.rb \
  app/controllers/department_employees_controller.rb \
  app/controllers/sick_day_entries_controller.rb \
  spec/requests/employees_spec.rb \
  spec/requests/department_employees_spec.rb \
  spec/requests/sick_day_entries_spec.rb
```
