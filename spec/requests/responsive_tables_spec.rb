# frozen_string_literal: true

require 'rails_helper'

# Phase 2 (tables/lists): every data surface must be mobile-first — no inline
# pixel grids, breakpoint-based grid columns for grid "tables", and an
# `overflow-x-auto` wrapper (or wrapping filters) for real `<table>` markup.
RSpec.describe 'Responsive tables', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:employee) { create(:employee) }

  before { sign_in user }

  def doc
    Nokogiri::HTML(response.body)
  end

  def grid_classes
    doc.css('div.grid').filter_map { |node| node['class'] }
  end

  describe 'employees index' do
    before { create(:employee) }

    it 'keeps the list grid free of inline pixel templates' do
      get employees_path

      expect(response.body).not_to include('grid-template-columns:')
    end

    it 'switches the header and rows through responsive breakpoints' do
      get employees_path

      list_grids = grid_classes.select { |klass| klass.include?('grid-cols-2') }
      expect(list_grids.size).to be >= 2
      expect(list_grids).to all(include('md:grid-cols-8'))
    end

    it 'replaces arbitrary 11px text with standard sizes' do
      get employees_path

      expect(response.body).not_to include('text-[11px]')
    end
  end

  describe 'sick days index' do
    before { create(:sick_day, employee: employee, period: Date.new(2026, 1, 1)) }

    it 'stacks the fixed five-column rows through breakpoints' do
      get employee_sick_days_path(employee)

      expect(response.body).not_to include('grid grid-cols-5')
      expect(response.body).to include('lg:grid-cols-5')
    end

    it 'hides the summary spacer cell until the desktop grid' do
      get employee_sick_days_path(employee)

      spacer = doc.at_css('[id^=summary_] > div:last-child')
      expect(spacer['class']).to include('hidden', 'lg:block')
    end
  end

  describe 'sick day form' do
    it 'stacks the five form cells on mobile' do
      get new_employee_sick_day_path(employee)

      expect(doc.at_css('form.grid')['class'])
        .to include('grid-cols-1', 'sm:grid-cols-2', 'lg:grid-cols-5')
    end
  end

  describe 'salaries index' do
    before do
      department = create(:department)
      create(:department_employee, department: department, employee: employee)
      create(:salary, employee: employee, department: department, period: Date.new(2025, 10, 1))
    end

    it 'keeps the twelve-column list responsive' do
      get employee_salaries_path(employee)

      expect(grid_classes).to all(include('md:grid-cols-12'))
      expect(grid_classes).to all(include('grid-cols-2'))
    end

    it 'lets the salary row actions wrap' do
      get employee_salaries_path(employee)

      actions = doc.css('div.grid > div').select { |node| node['class'].to_s.include?('md:col-span-2') }
                   .find { |node| node['class'].to_s.include?('flex') }
      expect(actions['class']).to include('flex-wrap')
    end
  end

  describe 'department page' do
    let(:department) { create(:department) }

    before do
      position = create(:position, department: department)
      create(:department_employee, employee: create(:employee), department: department, position: position)
    end

    it 'wraps the wide employee table for horizontal scrolling' do
      get department_path(department)

      expect(doc.at_css('div.overflow-x-auto > table')).not_to be_nil
    end
  end

  describe 'add employees to department' do
    let(:department) { create(:department) }

    it 'wraps the selection table for horizontal scrolling' do
      get new_department_employee_path(department_id: department.id)

      expect(doc.at_css('div.overflow-x-auto > table')).not_to be_nil
    end
  end

  describe 'reports index' do
    it 'wraps the results table for horizontal scrolling' do
      get reports_path

      expect(doc.at_css('div.overflow-x-auto > table')).not_to be_nil
    end

    it 'lets the filter form wrap instead of overflowing' do
      get reports_path

      expect(doc.at_css('.filter-form')['class']).to include('flex-wrap')
      expect(doc.at_css('.filter-form form')['class']).to include('flex-wrap')
    end
  end
end
