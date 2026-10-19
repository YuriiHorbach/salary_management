# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sick days editing', :js, type: :system do
  let(:user) { create(:user) }
  let(:employee) { create(:employee) }
  let!(:sick_day) do
    create(:sick_day, employee: employee, period: Date.new(2026, 1, 1),
                      pfu_amount_cents: 6_000, enterprise_amount_cents: 4_000)
  end

  before do
    create(:sick_day, employee: employee, period: Date.new(2026, 1, 1),
                      pfu_amount_cents: 1_000, enterprise_amount_cents: 0)
    login_as user, scope: :user
    visit employee_sick_days_path(employee)
  end

  it 'recalculates the period total after editing a sick day' do
    expect(page).to have_text('$110.00')

    within("#sick_day_#{sick_day.id}") do
      click_link '✏️'
    end

    within("#sick_day_#{sick_day.id}") do
      fill_in 'sick_day[pfu_amount]', with: '200.00'
      fill_in 'sick_day[enterprise_amount]', with: '100.00'
      click_button '✅'
    end

    expect(page).to have_text('$300.00')
    expect(page).to have_text('$310.00')
    expect(page).not_to have_text('$110.00')
  end
end
