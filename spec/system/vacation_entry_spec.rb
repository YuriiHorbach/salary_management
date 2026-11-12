# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Standalone vacation entry', :js, type: :system do
  let(:user) { create(:user, email: 'vacation_entry@example.com', password: '123456') }
  let!(:petrenko) do
    create(:employee, id_code: '1234567890', last_name: 'Петренко',
                      first_name: 'Іван', patronic_name: 'Іванович')
  end
  let!(:ivanenko) do
    create(:employee, id_code: '9876543210', last_name: 'Іваненко',
                      first_name: 'Марія', patronic_name: 'Петрівна')
  end

  before do
    login_as user, scope: :user
  end

  def submit_vacation(employee, period:, amount:)
    if page.has_css?("#vacation_employee_id_#{employee.id}", visible: :all)
      choose "vacation_employee_id_#{employee.id}"
    else
      select employee.full_name_with_id_code, from: 'vacation_employee_id'
    end
    fill_in 'vacation[period]', with: period
    fill_in 'vacation[vacation_amount]', with: amount
    click_button I18n.t('common.save')
  end

  it 'filters the employee list and creates a vacation for the selected employee' do
    visit new_vacation_entry_path

    expect(page).to have_select('vacation_employee_id',
                                with_options: [petrenko.full_name_with_id_code,
                                               ivanenko.full_name_with_id_code])

    fill_in 'employee_search', with: 'петренко'
    click_button I18n.t('common.search')

    expect(page).to have_text(petrenko.full_name_with_id_code)
    expect(page).not_to have_text(ivanenko.full_name_with_id_code)

    submit_vacation(petrenko, period: '2026-10-01', amount: '100.00')

    expect(page).to have_current_path(employee_vacations_path(petrenko), wait: 10)
    expect(page).to have_text('100,00')
  end

  it 'filters the embedded vacation report by month without leaving the entry page' do
    previous_month = Date.current.beginning_of_month - 1.month
    create(:vacation, employee: petrenko, period: previous_month)
    visit new_vacation_entry_path

    month_input = find('#vacation_report input[name="month"]')
    page.execute_script('arguments[0].value = arguments[1]', month_input, previous_month.strftime('%Y-%m'))
    click_button I18n.t('vacation_reports.index.filter')

    expect(page).to have_css("#vacation_report_employee_#{petrenko.id}")
    expect(page).to have_current_path(new_vacation_entry_path)
  end

  it 'opens the employee vacations page from the embedded report' do
    create(:vacation, employee: petrenko, period: Date.current.beginning_of_month)
    visit new_vacation_entry_path

    within("#vacation_report_employee_#{petrenko.id}") do
      click_link I18n.t('common.edit')
    end

    expect(page).to have_current_path(employee_vacations_path(petrenko))
  end

  it 'shows the matching employees by a partial id code and allows choosing one' do
    visit new_vacation_entry_path

    fill_in 'employee_search', with: '9876'
    click_button I18n.t('common.search')

    expect(page).to have_text(ivanenko.full_name_with_id_code)
    expect(page).not_to have_text(petrenko.full_name_with_id_code)

    choose "vacation_employee_id_#{ivanenko.id}"

    expect(page).to have_checked_field("vacation_employee_id_#{ivanenko.id}")
  end

  it 'opens the form from the additional navigation menu' do
    visit root_path

    find('details summary', text: I18n.t('navigation.more')).click
    click_link I18n.t('navigation.vacations')

    expect(page).to have_current_path(new_vacation_entry_path)
    expect(page).to have_text(I18n.t('vacation_entries.new.title'))
  end
end
