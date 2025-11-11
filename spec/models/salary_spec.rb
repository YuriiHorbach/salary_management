# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Salary, type: :model do
  let(:employee) { create(:employee) }
  let(:department) { create(:department) }
  let(:salary) do
    create(:salary, employee: employee, department: department, amount: 1000, paid_on: Date.new(2025, 5, 15))
  end

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:department).optional }
  end

  describe 'callbacks' do
    it 'updates employee total_salary after save' do
      employee.update(total_salary: 0)
      salary
      expect(employee.reload.total_salary).to eq(1000)
    end

    it 'updates employee total_salary after destroy' do
      salary
      expect do
        salary.destroy
      end.to change { employee.reload.total_salary }.by(-1000)
    end
  end

  describe '#month' do
    it 'returns YYYY-MM string' do
      expect(salary.month).to eq('2025-05')
    end
  end

  describe '#year' do
    it 'returns year as integer' do
      expect(salary.year).to eq(2025)
    end
  end

  describe '.monthly_sum_for_employee' do
    it 'returns sum of salaries grouped by year and month' do
      create(:salary, employee: employee, amount: 200, paid_on: Date.new(2025, 5, 1))
      create(:salary, employee: employee, amount: 300, paid_on: Date.new(2025, 6, 1))
      result = Salary.monthly_sum_for_employee(employee.id)
      expect(result.values.sum).to eq(employee.salaries.sum(:amount))
    end
  end
end
