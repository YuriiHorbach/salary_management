# frozen_string_literal: true

require 'rails_helper'

# Phase 1 responsive guards for the navbar: the expanded mobile menu must
# span the navbar width (not a squeezed side column), and dropdown panels
# must never bleed outside the viewport on narrow screens.
RSpec.describe 'Responsive navigation layout', :js, type: :system do
  let(:user) { create(:user, email: 'resp_nav@example.com', password: '123456') }

  after { resize_to(1400, 900) }

  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def sign_in_user
    login_as user, scope: :user
    visit root_path
    expect(page).to have_link(I18n.t('navigation.logout'), visible: :all)
  end

  def menu_width
    evaluate_script("document.getElementById('menu').getBoundingClientRect().width")
  end

  # Layout viewport in CSS pixels — excludes the classic 15px scrollbar that
  # headless Chrome reserves on Linux CI (macOS overlay scrollbars take 0px),
  # so hardcoded 390 would silently differ between environments.
  def viewport_width
    evaluate_script('document.documentElement.clientWidth')
  end

  def dropdown_labels
    [I18n.t('navigation.more'), I18n.t('navigation.reports'), I18n.t('navigation.settings')]
  end

  def open_dropdown_box(label)
    find('details summary', text: label).click
    box = evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelector('details[open] > div').getBoundingClientRect()
        return { left: rect.left, right: rect.right }
      })()
    JS
    find('details summary', text: label).click # close before the next one
    box
  end

  context 'when on a phone-sized viewport' do
    before { resize_to(390, 844) }

    it 'spreads the expanded menu across the navbar width' do
      sign_in_user
      find('#menu-toggle').click

      expect(menu_width).to be >= 0.9 * viewport_width
    end

    it 'keeps every dropdown panel inside the viewport' do
      sign_in_user
      find('#menu-toggle').click

      dropdown_labels.each do |label|
        box = open_dropdown_box(label)
        expect(box['left']).to be >= -1
        expect(box['right']).to be <= viewport_width + 1
      end
    end

    it 'does not introduce horizontal page scrolling' do
      sign_in_user
      find('#menu-toggle').click
      find('details summary', text: I18n.t('navigation.reports')).click

      scroll_width, client_width = evaluate_script(
        '[document.documentElement.scrollWidth, document.documentElement.clientWidth]'
      )
      expect(scroll_width).to be <= client_width + 1
    end
  end

  context 'when on a desktop viewport' do
    before { resize_to(1400, 900) }

    it 'keeps the menu inline at its natural width' do
      sign_in_user

      expect(menu_width).to be < 0.9 * 1400
      expect(menu_width).to be > 0
    end
  end
end
