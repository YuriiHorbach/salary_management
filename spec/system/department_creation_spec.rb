# frozen_string_literal: true

require 'rails_helper'

# Covers the department index Turbo Frame flow that previously raised a
# NameError because the inserted department card was rendered without the
# employee_counts local.
RSpec.describe 'Department creation', :js, type: :system do
  let(:user) { create(:user) }

  before { login_as user, scope: :user }

  it 'inserts the new department card with its employee count' do
    visit departments_path

    click_link I18n.t('departments.index.new')
    fill_in 'department[name]', with: 'New department'
    click_button I18n.t('departments.form.submit')

    expect(page).to have_link('New department')
    department = Department.find_by!(name: 'New department')

    within("#department_#{department.id}") do
      expect(page).to have_css("#department_#{department.id}_employee_count", text: '0')
    end
  end
end
