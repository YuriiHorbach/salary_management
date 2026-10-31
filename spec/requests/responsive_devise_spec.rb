# frozen_string_literal: true

require 'rails_helper'

# Phase 4 (Devise + leftovers): every reachable auth view follows the
# sessions-page pattern — a centered `max-w-md` form with full-width styled
# inputs and a `.btn` submit — the remember-me checkbox is spaced with `gap`
# instead of a fixed margin, and no arbitrary 11px text survives in reports.
# Note: User has no `:recoverable`/`:confirmable`/`:lockable` modules, so the
# passwords/confirmations/unlocks views have no routes and stay unreachable.
RSpec.describe 'Responsive devise views', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  def doc
    Nokogiri::HTML(response.body)
  end

  def expect_centered_auth_form(form)
    expect(form['class']).to include('max-w-md', 'mx-auto')
    expect(form.at_css('input[type=submit]')['class']).to include('btn', 'w-full')
  end

  describe 'sign in page' do
    it 'spaces the remember-me checkbox with a gap instead of a fixed margin' do
      get new_user_session_path

      checkbox = doc.at_css('#user_remember_me')
      expect(checkbox.parent['class']).to include('gap-2')
      expect(checkbox['class'].to_s).not_to include('mr-2')
    end

    it 'uses the centered form layout with styled fields' do
      get new_user_session_path

      expect_centered_auth_form(doc.at_css('form'))
      expect(doc.at_css('input[type=email]')['class']).to include('w-full')
    end
  end

  describe 'edit account page' do
    before { sign_in user }

    it 'uses the centered form layout with styled fields' do
      get edit_user_registration_path

      expect_centered_auth_form(doc.at_css('form'))
      expect(doc.at_css('input[name="user[current_password]"]')['class']).to include('w-full')
    end

    it 'styles the account cancellation block like the form' do
      get edit_user_registration_path

      expect(doc.at_css('input[name="_method"][value="delete"]')).not_to be_nil
      expect(doc.at_css('.btn-danger')['class']).to include('btn', 'btn-danger')
    end
  end

  describe 'detailed report' do
    before { sign_in user }

    it 'uses standard text sizes instead of arbitrary 11px' do
      book = AccountBook.create!(code: 'Б99')
      create(:employee, account_book: book)

      get detailed_reports_path

      expect(response.body).to include('employee_page_number')
      expect(response.body).not_to include('text-[11px]')
    end
  end
end
