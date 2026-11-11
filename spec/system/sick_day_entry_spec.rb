# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Standalone sick day entry', :js, type: :system do
  let(:user) { create(:user, email: 'sick_day_entry@example.com', password: '123456') }
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

  def expect_report_row(employee, pfu:, total:)
    within("#sick_day_report_employee_#{employee.id}") do
      expect(page).to have_text(employee.full_name)
      expect(page).to have_text(pfu)
      expect(page).to have_text(total)
    end
  end

  def submit_sick_day(employee, period:, pfu:, enterprise:)
    if page.has_css?("#sick_day_employee_id_#{employee.id}", visible: :all)
      choose "sick_day_employee_id_#{employee.id}"
    else
      select employee.full_name_with_id_code, from: 'sick_day_employee_id'
    end
    # Chrome/Selenium types month inputs one segment at a time, which can shift the
    # month when only the value changes. Setting it directly keeps the period exact.
    period_input = find('input[name="sick_day[period]"]')
    page.execute_script('arguments[0].value = arguments[1]', period_input, period)
    fill_in 'sick_day[pfu_amount]', with: pfu
    fill_in 'sick_day[enterprise_amount]', with: enterprise
    click_button I18n.t('common.save')
  end

  it 'filters the employee dropdown and creates a sick day for the selected employee' do
    visit new_sick_day_entry_path

    expect(page).to have_select('sick_day_employee_id',
                                with_options: [petrenko.full_name_with_id_code,
                                               ivanenko.full_name_with_id_code])

    fill_in 'employee_search', with: 'петренко'
    click_button I18n.t('common.search')

    expect(page).to have_text(petrenko.full_name_with_id_code)
    expect(page).not_to have_text(ivanenko.full_name_with_id_code)

    submit_sick_day(petrenko, period: Date.current.strftime('%Y-%m'), pfu: '60.00', enterprise: '40.00')

    expect(page).to have_current_path(new_sick_day_entry_path(month: Date.current.strftime('%Y-%m')), wait: 10)

    expect_report_row(petrenko, pfu: '60,00', total: '100,00')
  end

  it 'filters the embedded report by month without leaving the entry page' do
    previous_month = Date.current.beginning_of_month - 1.month
    create(:sick_day, employee: petrenko, period: previous_month, pfu_amount: 60, enterprise_amount: 40)
    visit new_sick_day_entry_path

    month_input = find('#sick_day_report input[name="month"]')
    page.execute_script('arguments[0].value = arguments[1]', month_input, previous_month.strftime('%Y-%m'))
    click_button I18n.t('sick_day_reports.index.filter')

    expect(page).to have_css("#sick_day_report_employee_#{petrenko.id}")
    expect(page).to have_current_path(new_sick_day_entry_path)
  end

  it 'opens the employee sick days page from the embedded report' do
    create(:sick_day, employee: petrenko, period: Date.current.beginning_of_month)
    visit new_sick_day_entry_path

    within("#sick_day_report_employee_#{petrenko.id}") do
      click_link I18n.t('common.edit')
    end

    expect(page).to have_current_path(employee_sick_days_path(petrenko))
  end

  it 'shows the matching employees by a partial id code and allows choosing one' do
    visit new_sick_day_entry_path

    fill_in 'employee_search', with: '9876'
    click_button I18n.t('common.search')

    expect(page).to have_text(ivanenko.full_name_with_id_code)
    expect(page).not_to have_text(petrenko.full_name_with_id_code)

    choose "sick_day_employee_id_#{ivanenko.id}"

    expect(page).to have_checked_field("sick_day_employee_id_#{ivanenko.id}")
  end

  it 'opens the form from the additional navigation menu' do
    visit root_path

    find('details summary', text: I18n.t('navigation.more')).click
    click_link I18n.t('navigation.sick_days')

    expect(page).to have_current_path(new_sick_day_entry_path)
    expect(page).to have_text(I18n.t('sick_day_entries.new.title'))
  end
end
