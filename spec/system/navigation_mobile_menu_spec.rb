# frozen_string_literal: true

require 'rails_helper'

# Covers the mobile (below `lg`) navigation menu: the hamburger toggle must
# actually open/close the collapsed menu, expose correct ARIA state, and the
# desktop layout must keep the menu inline without the toggle.
RSpec.describe 'Navigation mobile menu', :js, type: :system do
  let(:user) { create(:user, email: 'mobile_menu@example.com', password: '123456') }

  # Capybara reuses the browser across examples, so always restore the
  # default desktop window size after a resized example.
  after { resize_to(1400, 900) }

  # Resizes the browser window directly through Selenium (Capybara has no
  # stable session-level resize API across versions).
  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def sign_in_user
    login_as user, scope: :user
    visit root_path
    # The logout link lives inside the menu, which is collapsed on mobile.
    expect(page).to have_link(I18n.t('navigation.logout'), visible: :all)
  end

  context 'when on a phone-sized viewport' do
    before { resize_to(390, 844) }

    it 'shows the hamburger and keeps the menu collapsed' do
      sign_in_user

      expect(page).to have_css('#menu-toggle', visible: true)
      expect(page).to have_css('#menu', visible: :hidden)
      # The home page has its own "Departments" CTA, so scope to the menu.
      expect(page).to have_css("#menu a[href='#{departments_path}']", visible: :hidden)
    end

    it 'expands the menu when the hamburger is clicked' do
      sign_in_user

      find('#menu-toggle').click

      expect(page).to have_css('#menu', visible: true)
      expect(page).to have_link(I18n.t('navigation.departments'), visible: true)
      expect(find('#menu-toggle')['aria-expanded']).to eq('true')
    end

    it 'collapses the menu when the hamburger is clicked again' do
      sign_in_user
      find('#menu-toggle').click
      expect(page).to have_css('#menu', visible: true)

      find('#menu-toggle').click

      expect(page).to have_css('#menu', visible: :hidden)
      expect(find('#menu-toggle')['aria-expanded']).to eq('false')
    end

    it 'collapses the menu on the Escape key' do
      sign_in_user
      find('#menu-toggle').click
      expect(page).to have_css('#menu', visible: true)

      send_keys(:escape)

      expect(page).to have_css('#menu', visible: :hidden)
    end

    it 'collapses the menu when clicking outside the navbar' do
      sign_in_user
      find('#menu-toggle').click
      expect(page).to have_css('#menu', visible: true)

      # A real document-level click outside the nav (body is never inside it).
      page.execute_script(
        "document.body.dispatchEvent(new MouseEvent('click', { bubbles: true }))"
      )

      expect(page).to have_css('#menu', visible: :hidden)
    end

    it 'navigates from an expanded mobile menu' do
      sign_in_user
      find('#menu-toggle').click

      # Scope to the menu: the home page also links to Departments.
      find('#menu').click_link I18n.t('navigation.departments')

      expect(page).to have_current_path(departments_path)
    end
  end

  context 'when on a desktop viewport' do
    before { resize_to(1400, 900) }

    it 'shows the menu inline and hides the hamburger' do
      sign_in_user

      expect(page).to have_css('#menu', visible: true)
      expect(page).to have_link(I18n.t('navigation.departments'), visible: true)
      expect(page).to have_css('#menu-toggle', visible: :hidden)
    end
  end
end
