# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sick days deletion (native confirm)', :js, type: :system do
  let(:user) { create(:user, email: 'sick_days_delete@example.com', password: '123456') }
  let(:employee) { create(:employee) }

  def sign_in
    login_as user, scope: :user
    visit root_path
    expect(page).to have_link('Logout')
  end

  def create_sick_day(period:, pfu:, enterprise:)
    visit new_employee_sick_day_path(employee)
    fill_in 'sick_day[period]', with: period
    fill_in 'sick_day[pfu_amount]', with: pfu
    fill_in 'sick_day[enterprise_amount]', with: enterprise
    click_button '✅'
    expect(page).to have_current_path(employee_sick_days_path(employee), wait: 10)
  end

  def create_sick_days(count)
    count.times do |i|
      create_sick_day(period: format('2026-%02d', i + 1), pfu: 1000 + i, enterprise: 2000 + i)
    end
  end

  def alert_present?
    page.driver.browser.switch_to.alert
    true
  rescue Selenium::WebDriver::Error::NoSuchAlertError
    false
  end

  def delete_first_with_confirmation
    frames_before = all('turbo-frame').count
    first('button', text: '❌').click
    expect(alert_present?).to be(true)

    count = 0
    while alert_present?
      count += 1
      page.driver.browser.switch_to.alert.accept
      sleep 0.2
    end

    expect(all('turbo-frame').count).to eq(frames_before - 1)
    count
  end

  it 'creates several sick days and deletes each with a single OK' do
    sign_in
    create_sick_days(4)
    expect(employee.sick_days.count).to eq(4)

    counts = Array.new(4) { delete_first_with_confirmation }

    expect(counts).to eq([1, 1, 1, 1])
    expect(employee.sick_days.count).to eq(0)
  end

  it 'keeps the sick day when the confirmation is cancelled' do
    sign_in
    create_sick_day(period: '2026-01', pfu: 1000, enterprise: 2000)

    first('button', text: '❌').click
    expect(alert_present?).to be(true)
    page.driver.browser.switch_to.alert.dismiss

    expect(page).to have_css('turbo-frame', count: 1)
    expect(employee.sick_days.count).to eq(1)
  end

  it 'reports that WebDriver Enter does not confirm the native dialog' do
    sign_in
    create_sick_day(period: '2026-01', pfu: 1000, enterprise: 2000)

    first('button', text: '❌').click
    expect(alert_present?).to be(true)

    begin
      page.driver.browser.action.send_keys(:enter).perform
    rescue Selenium::WebDriver::Error::UnexpectedAlertOpenError
      # ChromeDriver rejects keyboard input while a native dialog is open.
    end

    sleep 0.5

    # The input command dismissed the dialog without confirming the deletion.
    expect(alert_present?).to be(false)
    expect(employee.sick_days.reload.count).to eq(1)
  end
end
