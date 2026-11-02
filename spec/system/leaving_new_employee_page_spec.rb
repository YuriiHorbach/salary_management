# frozen_string_literal: true

require 'rails_helper'

# Phase A fix guards: both "Back to employees" and in-form "Cancel" must leave
# /employees/new via a full-page visit. Previously they carried
# data-turbo-frame="new_employee", so Turbo navigated the form's
# <turbo-frame id="new_employee">; the employees index has no such frame, so
# Turbo 8 rendered "Content missing" and the URL never changed.
RSpec.describe 'Leaving the new employee page', :js, type: :system do
  let(:user) { create(:user) }

  before do
    login_as user, scope: :user
    visit new_employee_path
  end

  it 'returns to the employees index when Back to employees is clicked' do
    expect(page).to have_link(I18n.t('employees.new.back'))

    click_link I18n.t('employees.new.back')

    expect(page).to have_current_path(employees_path, wait: 5)
  end

  it 'returns to the employees index when Cancel is clicked in the form' do
    expect(page).to have_link(I18n.t('employees.form.cancel'))

    click_link I18n.t('employees.form.cancel')

    expect(page).to have_current_path(employees_path, wait: 5)
  end
end
