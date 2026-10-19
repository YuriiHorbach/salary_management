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

  def submit_sick_day(employee, period:, pfu:, enterprise:)
    select employee.full_name_with_id_code, from: 'sick_day_employee_id'
    fill_in 'sick_day[period]', with: period
    fill_in 'sick_day[pfu_amount]', with: pfu
    fill_in 'sick_day[enterprise_amount]', with: enterprise
    click_button 'Зберегти'
  end

  it 'filters the employee dropdown and creates a sick day for the selected employee' do
    visit new_sick_day_entry_path

    expect(page).to have_select('sick_day_employee_id',
                                with_options: [petrenko.full_name_with_id_code,
                                               ivanenko.full_name_with_id_code])

    fill_in 'employee_search', with: 'петренко'
    click_button 'Пошук'

    expect(page).to have_select('sick_day_employee_id', with_options: [petrenko.full_name_with_id_code])
    expect(page).not_to have_select('sick_day_employee_id', with_options: [ivanenko.full_name_with_id_code])

    submit_sick_day(petrenko, period: '2026-10', pfu: '60.00', enterprise: '40.00')

    expect(page).to have_current_path(employee_sick_days_path(petrenko), wait: 10)
    expect(page).to have_text('$100.00')
  end

  it 'opens the form from the additional navigation menu' do
    visit root_path

    find('details summary', text: 'Додатково').click
    click_link 'Лікарняні'

    expect(page).to have_current_path(new_sick_day_entry_path)
    expect(page).to have_text('Додати лікарняний')
  end
end
