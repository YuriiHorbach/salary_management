# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Department, type: :model do
  describe '#period_salaries' do
    let(:department) { create(:department) }
    let(:employee) { create(:employee) }
    let(:position) { create(:position, department: department) }
    let(:period) { Date.new(2025, 3, 1) }

    before do
      create(:department_employee, employee: employee, department: department, position: position)
      create(:salary, employee: employee, department: department, position: position,
                      amount_cents: 50_000, period: period)
      create(:salary, employee: employee, department: department,
                      amount_cents: 100_000, period: period)
      create(:salary, employee: employee, department: department, position: position,
                      amount_cents: 900_000, period: Date.new(2025, 4, 1))
    end

    it 'returns every salary of the department for the given period' do
      expect(department.period_salaries(period).sum(:amount_cents)).to eq(150_000)
    end

    it 'scopes the salaries to the given position' do
      expect(department.period_salaries(period, position: position).sum(:amount_cents)).to eq(50_000)
    end

    it 'keeps the period scope when a position is given' do
      expect(department.period_salaries(period, position: position).pluck(:period).uniq)
        .to contain_exactly(period)
    end

    it 'accepts a position id as well as a position record' do
      expect(department.period_salaries(period, position: position.id).sum(:amount_cents)).to eq(50_000)
    end
  end

  describe '#monthly_total' do
    let(:department) { create(:department) }
    let(:employee) { create(:employee) }
    let(:position) { create(:position, department: department) }
    let(:period) { Date.new(2025, 3, 1) }

    before do
      create(:department_employee, employee: employee, department: department, position: position)
      create(:salary, employee: employee, department: department, position: position,
                      amount_cents: 50_000, period: period)
      create(:salary, employee: employee, department: department,
                      amount_cents: 100_000, period: period)
    end

    it 'returns the whole department total when no position is given' do
      expect(department.monthly_total(period)).to eq(1500.0)
    end

    it 'returns the position total when a position is given' do
      expect(department.monthly_total(period, position: position)).to eq(500.0)
    end
  end

  describe '.employee_counts' do
    it 'returns the number of distinct employees for each department' do
      department = create(:department)
      other_department = create(:department)
      position = create(:position, department: department)
      employee = create(:employee)
      other_employee = create(:employee)

      create(:department_employee, employee: employee, department: department, position: position)
      create(:department_employee, employee: employee, department: department)
      create(:department_employee, employee: other_employee, department: other_department)

      expect(described_class.employee_counts).to include(
        department.id => 1,
        other_department.id => 1
      )
    end

    it 'omits departments without employees' do
      department = create(:department)

      expect(described_class.employee_counts).not_to have_key(department.id)
    end
  end
end
