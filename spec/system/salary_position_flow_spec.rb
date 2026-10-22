# frozen_string_literal: true

require 'rails_helper'

# Covers the flow from the department page to the employee salary page: a
# position assigned there must be used when the salary is added, and editing a
# salary must keep the persisted amount while the position is changed.
RSpec.describe 'Salary position flow', :js, type: :system do
  let(:user) { create(:user) }
  let(:department) { create(:department, name: 'Відділ') }
  let(:employee) do
    create(:employee, last_name: 'Kovalenko', first_name: 'Iryna', patronic_name: 'Petrivna')
  end
  let(:position) { create(:position, department: department, position_name: 'Engineer') }
  let(:other_position) { create(:position, department: department, position_name: 'Manager') }
  let(:period) { Date.new(2025, 10, 1) }

  before do
    create(:department_employee, employee: employee, department: department)
    login_as user, scope: :user
  end

  it 'creates a position, assigns it and keeps it on the added salary' do
    create_and_assign_position('Engineer')
    assigned_position = Position.find_by!(position_name: 'Engineer')

    expect(employee_row).to have_text('Engineer')
    add_salary('1000', assigned_position)
    expect(page).to have_css("#salary_cell_employee_#{employee.id}", text: '1000,00')
    visit employee_salaries_path(employee, period: '2025-10')
    expect(page).to have_text('1000,00').and have_text('Engineer')
  end

  it 'adds a salary for each position without filtering the department page' do
    create(:department_employee, employee: employee, department: department, position: position)
    create(:department_employee, employee: employee, department: department, position: other_position)

    visit department_path(department, period: '2025-10')
    add_salary('1000', position)
    add_salary('500', other_position)

    expect(page).to have_css("#salary_position_#{employee.id}_#{position.id}", text: '1000,00')
    expect(page).to have_css("#salary_position_#{employee.id}_#{other_position.id}", text: '500,00')
    current_uri = URI.parse(current_url)
    expect(current_uri.path).to eq(department_path(department))
    expect(current_uri.query).to include('period=2025-10')
    expect(current_uri.query).not_to include('position=')
  end

  it 'does not submit when a position is chosen before the amount is entered' do
    create(:department_employee, employee: employee, department: department, position: position)
    create(:department_employee, employee: employee, department: department, position: other_position)

    visit new_employee_salary_path(employee, department_id: department.id, period: '2025-10')
    select 'Manager', from: 'salary[position_id]'

    expect(page).to have_no_text('Amount is not a number')
    fill_in 'salary[amount]', with: '500'
    click_button 'Зберегти'

    expect(page).to have_css("#salary_position_#{employee.id}_#{other_position.id}", text: '500,00')
    expect(Salary.last.position).to eq(other_position)
  end

  it 'shows the amount when editing a salary to assign a position' do
    create(:department_employee, employee: employee, department: department, position: position)
    salary = create(:salary, employee: employee, department: department,
                             amount_cents: 100_000, period: period)

    visit employee_salaries_path(employee, period: '2025-10')
    within("#salary_#{salary.id}") { click_link 'Edit' }

    amount = find('input[name="salary[amount]"]')
    expect(amount.value.to_f).to eq(1000.0)

    select 'Engineer', from: 'salary[position_id]'
    click_button 'Save Salary Record'

    expect(URI.parse(current_url).path).to eq(employee_salaries_path(employee))

    within("#salary_#{salary.id}") do
      expect(page).to have_text('1000,00').and have_text('Engineer')
    end
  end

  def employee_row
    find("#department_employee_#{employee.id}")
  end

  def create_and_assign_position(name)
    visit department_path(department, period: '2025-10')
    within(employee_row) { click_link 'Додати посаду' }
    fill_in 'position[position_name]', with: name
    click_button 'Додати посаду'
    expect(page).to have_css('input[name="position_ids[]"]:checked')
    click_button 'Зберегти'
  end

  def add_salary(amount, position)
    within("#salary_position_#{employee.id}_#{position.id}") { click_link '+ Додати' }
    fill_in 'salary[amount]', with: amount
    click_button 'Зберегти'
  end
end
