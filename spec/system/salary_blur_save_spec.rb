# frozen_string_literal: true

require 'rails_helper'

# Verifies the inline salary form saves when focus leaves the whole form, while
# still allowing the user to move between the amount and position fields, use
# the explicit Save button, and recover from validation errors.
RSpec.describe 'Inline salary blur-to-save', :js, type: :system do
  let(:user) { create(:user) }
  let(:department) { create(:department, name: 'Відділ') }
  let(:employee) do
    create(:employee, last_name: 'Kovalenko', first_name: 'Iryna', patronic_name: 'Petrivna')
  end
  let(:position) { create(:position, department: department, position_name: 'Engineer') }
  let(:other_position) { create(:position, department: department, position_name: 'Manager') }
  let(:period) { '2025-10' }

  before do
    create(:department_employee, employee: employee, department: department)
    login_as user, scope: :user
  end

  it 'saves when focus leaves the inline form' do
    create(:department_employee, employee: employee, department: department, position: position)

    open_inline_salary_for(position)
    fill_in 'salary[amount]', with: '1000'
    blur_inline_form

    expect(page).to have_no_css('input[name="salary[amount]"]')
    expect(page).to have_css("#salary_position_#{employee.id}_#{position.id}", text: '1000,00')
    expect(page).to have_css('#department_total', text: '1000,00')
    expect(Salary.where(employee: employee).count).to eq(1)
  end

  it 'does not submit while choosing a position inside the form' do
    create(:department_employee, employee: employee, department: department, position: position)
    create(:department_employee, employee: employee, department: department, position: other_position)

    open_inline_salary_for(position)
    fill_in 'salary[amount]', with: '1000'
    focus_position_select
    select 'Manager', from: 'salary[position_id]'

    expect(page).to have_css('input[name="salary[amount]"]')
    expect(Salary.where(employee: employee)).to be_empty

    blur_inline_form

    expect(page).to have_no_css('input[name="salary[amount]"]')
    salary = Salary.find_by!(employee: employee)
    expect(salary.position).to eq(other_position)
    expect(salary.amount_cents).to eq(100_000)
  end

  it 'does not create a salary when the amount is empty' do
    create(:department_employee, employee: employee, department: department, position: position)

    open_inline_salary_for(position)
    blur_inline_form

    expect(page).to have_css('input[name="salary[amount]"]')
    expect(page).to have_no_css('p.text-red-600')
    expect(Salary.where(employee: employee)).to be_empty
  end

  it 'submits exactly once when the save button is clicked' do
    create(:department_employee, employee: employee, department: department, position: position)

    open_inline_salary_for(position)
    fill_in 'salary[amount]', with: '1000'
    click_button I18n.t('salaries.inline_form.save')

    expect(page).to have_no_css('input[name="salary[amount]"]')
    expect(page).to have_no_css('p.text-red-600')
    expect(Salary.where(employee: employee).count).to eq(1)
  end

  it 'keeps the inline form with validation errors when blur submission fails' do
    create(:department_employee, employee: employee, department: department, position: position)
    create(:salary, employee: employee, department: department, position: position,
                    amount_cents: 100_000, period: Date.new(2025, 10, 1))

    visit new_employee_salary_path(employee, department_id: department.id,
                                             period: period, position_id: position.id)
    fill_in 'salary[amount]', with: '1234.56'
    page.execute_script('document.activeElement.blur()')

    expect(page).to have_css('input[name="salary[amount]"]')
    expect(page).to have_text(I18n.t('activerecord.errors.models.salary.attributes.period.period_taken'))
    expect(Salary.where(employee: employee).count).to eq(1)
  end

  def open_inline_salary_for(position)
    visit department_path(department, period: period)
    within("#salary_position_#{employee.id}_#{position.id}") do
      click_link I18n.t('departments.salary_cell.add')
    end
  end

  def focus_position_select
    page.execute_script(
      "document.querySelector('select[name=\"salary[position_id]\"]').focus()"
    )
  end

  def blur_inline_form
    find('h1', text: department.name).click
  end
end
