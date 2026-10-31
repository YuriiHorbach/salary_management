# frozen_string_literal: true

require 'rails_helper'

# Phase 1 guard: `.btn` utilities must cooperate with Tailwind responsive
# width helpers (`w-full sm:w-auto`) and be painted from the Tailwind
# palette (they are compiled with `@apply`, not hardcoded colors).
RSpec.describe 'Responsive buttons', :js, type: :system do
  let(:user) { create(:user, email: 'btn_resp@example.com', password: '123456') }

  after { resize_to(1400, 900) }

  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  # The "Back" link on employees/new carries `btn btn-primary ... w-full sm:w-auto`.
  def visit_back_button
    login_as user, scope: :user
    visit new_employee_path
    find('a', text: I18n.t('employees.new.back'))
  end

  def width_of(element)
    evaluate_script('arguments[0].getBoundingClientRect().width', element.native)
  end

  context 'when on a phone-sized viewport' do
    before { resize_to(390, 844) }

    it 'stretches w-full sm:w-auto buttons across the content width' do
      button = visit_back_button
      main_width = evaluate_script("document.querySelector('main').getBoundingClientRect().width")

      expect(width_of(button)).to be >= 0.9 * main_width
    end
  end

  context 'when on a desktop viewport' do
    before { resize_to(1400, 900) }

    it 'shrinks sm:w-auto buttons back to their content width' do
      button = visit_back_button
      main_width = evaluate_script("document.querySelector('main').getBoundingClientRect().width")

      expect(width_of(button)).to be < 0.5 * main_width
    end

    it 'paints .btn-primary with the Tailwind green-600 utility color' do
      button = visit_back_button
      background = evaluate_script('getComputedStyle(arguments[0]).backgroundColor', button.native)

      expect(background).to eq('rgb(22, 163, 74)')
    end
  end
end
