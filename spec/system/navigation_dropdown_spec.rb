# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Navigation dropdown', type: :system, js: true do
  let(:user) { create(:user, email: 'test@example.com', password: '123456') }

  def sign_in_user
    visit new_user_session_path
    fill_in 'user[email]', with: user.email
    fill_in 'user[password]', with: user.password
    click_button 'Log in'
    expect(page).to have_current_path(root_path)
  end

  it 'dropdown panel uses absolute positioning under parent details' do
    sign_in_user
    visit root_path

    find('details summary', text: 'Звіти').click
    sleep 0.2

    panel_position = evaluate_script("getComputedStyle(document.querySelector('details[open] > div')).position")
    expect(panel_position).to eq('absolute')

    panel_top = evaluate_script("document.querySelector('details[open] > div').getBoundingClientRect().top").to_i
    summary_bottom = evaluate_script("document.querySelector('details[open] summary')
                     .getBoundingClientRect().bottom")
                     .to_i
    expect(panel_top).to be_within(10).of(summary_bottom)

    panel_left = evaluate_script("document.querySelector('details[open] > div').getBoundingClientRect().left").to_i
    summary_left = evaluate_script("document.querySelector('details[open] summary').getBoundingClientRect().left").to_i
    expect(panel_left).to be_within(10).of(summary_left)
  end

  it 'does not expand navbar height when dropdowns open' do
    sign_in_user
    visit root_path

    nav_height_before = evaluate_script("document.querySelector('nav').getBoundingClientRect().height").to_i
    details_width_before = evaluate_script("document.querySelector('details').getBoundingClientRect().width").to_i

    find('details summary', text: 'Звіти').click
    sleep 0.2

    nav_height_after = evaluate_script("document.querySelector('nav').getBoundingClientRect().height").to_i
    details_width_after = evaluate_script("document.querySelector('details').getBoundingClientRect().width").to_i

    expect(nav_height_after).to be_within(1).of(nav_height_before)
    expect(details_width_after).to eq(details_width_before)
  end

  it 'opens Звіти dropdown and shows sub-links' do
    sign_in_user
    visit root_path

    expect(page).not_to have_text('Зведений звіт')
    expect(page).not_to have_text('Детальний звіт')

    find('details summary', text: 'Звіти').click

    expect(page).to have_text('Зведений звіт')
    expect(page).to have_text('Детальний звіт')
  end

  it 'navigates to Зведений звіт when clicked' do
    sign_in_user
    visit root_path

    find('details summary', text: 'Звіти').click
    click_link 'Зведений звіт'

    expect(page).to have_current_path(summary_reports_path)
    expect(page).to have_text('Зведений звіт по зарплатах (Pivot)')
  end

  it 'navigates to Детальний звіт when clicked' do
    sign_in_user
    visit root_path

    find('details summary', text: 'Звіти').click
    click_link 'Детальний звіт'

    expect(page).to have_current_path(detailed_reports_path)
    expect(page).to have_text('Детальний звіт по співробітникам')
  end

  it 'closes dropdown when clicking outside' do
    sign_in_user
    visit root_path

    find('details summary', text: 'Звіти').click
    expect(page).to have_text('Зведений звіт')

    find('nav').click

    expect(page).not_to have_text('Зведений звіт')
  end

  it 'closes one dropdown when another opens' do
    sign_in_user
    visit root_path

    find('details summary', text: 'Звіти').click
    expect(page).to have_text('Зведений звіт')

    find('details summary', text: 'Налаштування').click
    expect(page).not_to have_text('Зведений звіт')
    expect(page).to have_text('Налаштування системи')
  end

  it 'closes dropdown on Escape key' do
    sign_in_user
    visit root_path

    find('details summary', text: 'Звіти').click
    expect(page).to have_text('Зведений звіт')

    send_keys :escape
    sleep 0.1

    expect(page).not_to have_text('Зведений звіт')
  end
end
