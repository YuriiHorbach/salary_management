# frozen_string_literal: true

require 'rails_helper'

# Covers the client-side highlight toggle on the department index page. Each
# department card exposes a checkbox that turns the card green while checked
# and restores the default styling when unchecked.
RSpec.describe 'Department card highlight', :js, type: :system do
  let(:user) { create(:user) }
  let!(:department) { create(:department, name: 'Highlighted department') }

  before { login_as user, scope: :user }

  it 'switches the card to green while the checkbox is checked' do
    visit departments_path

    within("#department_#{department.id}") do
      expect(page).to have_css('.bg-white')
      expect(page).not_to have_css('.bg-green-50')

      check I18n.t('departments.card.mark')

      expect(page).to have_css('.bg-green-50')
      expect(page).not_to have_css('.bg-white')
    end
  end

  it 'restores the default colour when the checkbox is unchecked' do
    visit departments_path

    within("#department_#{department.id}") do
      check I18n.t('departments.card.mark')
      expect(page).to have_css('.bg-green-50')

      uncheck I18n.t('departments.card.mark')

      expect(page).to have_css('.bg-white')
      expect(page).not_to have_css('.bg-green-50')
    end
  end
end
