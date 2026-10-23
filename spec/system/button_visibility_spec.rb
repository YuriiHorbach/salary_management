# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Button visibility', type: :system, js: true do
  let(:user) { create(:user, email: 'btn_test@example.com', password: '123456') }

  def sign_in_user
    login_as user, scope: :user
    visit root_path
    expect(page).to have_link('Logout')
  end

  it 'buttons on settings/account_books have black text and colored background' do
    sign_in_user
    visit settings_account_books_path

    # Find the "Add new" button
    add_btn = page.find('a', text: I18n.t('settings.account_books.index.add'))
    expect(add_btn).to be_visible

    # Check computed styles via JavaScript
    color = evaluate_script("getComputedStyle(arguments[0]).color", add_btn.native)
    bg_color = evaluate_script("getComputedStyle(arguments[0]).backgroundColor", add_btn.native)
    width = evaluate_script("arguments[0].getBoundingClientRect().width", add_btn.native)
    height = evaluate_script("arguments[0].getBoundingClientRect().height", add_btn.native)

    # Text should be black (rgb(0, 0, 0))
    expect(color).to eq('rgb(0, 0, 0)')

    # Background should not be transparent or white for primary buttons
    expect(bg_color).not_to eq('rgba(0, 0, 0, 0)')
    expect(bg_color).not_to eq('rgb(255, 255, 255)')

    # Button should have visible dimensions
    expect(width).to be > 0
    expect(height).to be > 0
  end

  it 'buttons on settings/territory_signs have black text' do
    sign_in_user
    visit settings_territory_signs_path

    add_btn = page.find('a', text: I18n.t('settings.account_books.index.add'))
    expect(add_btn).to be_visible

    color = evaluate_script("getComputedStyle(arguments[0]).color", add_btn.native)
    expect(color).to eq('rgb(0, 0, 0)')
  end

  it 'buttons on settings/dashboard have black text' do
    sign_in_user
    visit settings_root_path

    add_brigade_btn = page.find('a', text: I18n.t('settings.dashboard.add_brigade'))
    expect(add_brigade_btn).to be_visible

    color = evaluate_script("getComputedStyle(arguments[0]).color", add_brigade_btn.native)
    expect(color).to eq('rgb(0, 0, 0)')

    add_book_btn = page.find('a', text: I18n.t('settings.dashboard.add_book'))
    expect(add_book_btn).to be_visible

    color = evaluate_script("getComputedStyle(arguments[0]).color", add_book_btn.native)
    expect(color).to eq('rgb(0, 0, 0)')
  end

  it 'nav bar buttons keep white text (not changed)' do
    sign_in_user
    visit settings_account_books_path

    # Nav bar should still have white text elements (we didn't touch the nav)
    nav_white_text = evaluate_script("Array.from(document
                                           .querySelectorAll('nav a'))
                                           .some(el => getComputedStyle(el)
                                           .color === 'rgb(255, 255, 255)')
                                     ")
    expect(nav_white_text).to be true
  end
end
