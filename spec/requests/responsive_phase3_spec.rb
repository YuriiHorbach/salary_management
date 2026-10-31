# frozen_string_literal: true

require 'rails_helper'

# Phase 3 (smaller pages/forms): mobile-first grids everywhere — no inverted
# breakpoint stacks, no fixed column counts without a stacked mobile fallback,
# no fixed pixel margins (`ml-4`) or fixed heights in wrapping action rows.
RSpec.describe 'Responsive small pages', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:employee) { create(:employee) }

  before { sign_in user }

  def doc
    Nokogiri::HTML(response.body)
  end

  describe 'departments index' do
    it 'stacks department cards on mobile first' do
      get departments_path

      expect(doc.at_css('div.grid')['class'])
        .to include('grid-cols-1', 'sm:grid-cols-2', 'lg:grid-cols-3')
    end
  end

  describe 'vacation form' do
    it 'stacks the four form cells on mobile' do
      get new_employee_vacation_path(employee)

      expect(doc.at_css('form.grid')['class'])
        .to include('grid-cols-1', 'sm:grid-cols-2', 'lg:grid-cols-4')
    end
  end

  describe 'salary edit form' do
    let(:department) { create(:department) }
    let!(:salary) do
      create(:department_employee, department: department, employee: employee)
      create(:salary, employee: employee, department: department)
    end

    it 'stacks the three fields on mobile' do
      get edit_employee_salary_path(employee, salary)

      expect(doc.at_css('form .grid')['class'])
        .to include('grid-cols-1', 'sm:grid-cols-2', 'lg:grid-cols-6')
    end
  end

  describe 'add employees to department' do
    it 'lets the filter submit buttons wrap instead of fixing the row height' do
      department = create(:department)

      get new_department_employee_path(department_id: department.id)

      expect(doc.at_css('input[type=submit]').parent['class']).to include('flex-wrap')
      expect(response.body).not_to include('space-x-2 h-10')
    end
  end

  describe 'employee page' do
    it 'uses breakpoint-based columns without fixed label widths' do
      get employee_path(employee)

      expect(doc.at_css('div.grid')['class']).to include('grid-cols-1', 'sm:grid-cols-2')
      expect(response.body).not_to include('grid-cols-[8rem_1fr]', 'w-32')
    end

    it 'lets the card actions wrap with gap spacing' do
      get employee_path(employee)

      actions = doc.at_css('div.grid div.flex')
      expect(actions['class']).to include('flex-wrap', 'gap-2')
      expect(actions['class']).not_to include('space-x-2')
    end
  end

  describe 'settings list pages' do
    it 'replaces the fixed margin between territory sign actions with a gap' do
      create(:territory_sign)

      get settings_territory_signs_path

      expect(response.body).not_to include('ml-4')
    end

    it 'replaces the fixed margin between account book actions with a gap' do
      create(:account_book)

      get settings_account_books_path

      expect(response.body).not_to include('ml-4')
    end
  end
end
