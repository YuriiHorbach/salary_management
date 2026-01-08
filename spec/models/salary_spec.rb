# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Salary, type: :model do
  let(:employee) { create(:employee) }
  let(:department) { create(:department, name: 'Test Dept') }
  let(:salary) do
    create(:salary, employee: employee, department: department, amount: 1000, paid_on: Date.new(2025, 5, 15))
  end

  let!(:salary_jan_dev) do
    create(:salary, department: department, paid_on: Date.new(2025, 1, 1), amount: 100)
  end
  let!(:salary_feb_other) do
    create(:salary, department: create(:department, name: 'Other'), paid_on: Date.new(2025, 2, 1), amount: 200)
  end
  let!(:salary_2024) do
    create(:salary, department: department, paid_on: Date.new(2024, 5, 1), amount: 300)
  end

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:department).optional }
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

  describe 'scopes' do
    describe '.by_month' do
      it 'returns salaries paid in the specified month' do
        expect(Salary.by_month(1)).to contain_exactly(salary_jan_dev)
      end

      it 'returns all salaries if month is nil or blank' do
        expect(Salary.by_month(nil).count).to eq(Salary.count)
      end
    end

    describe '.by_year' do
      it 'returns salaries paid in the specified year' do
        expect(Salary.by_year(2024)).to contain_exactly(salary_2024)
      end

      it 'returns all salaries if year is nil or blank' do
        expect(Salary.by_year('')).to eq(Salary.all)
      end
    end

    describe '.by_department' do
      let(:other_department) { create(:department, name: 'Other Test Dept') }
      let!(:salary_other_dept) { create(:salary, department: other_department) }

      it 'returns salaries belonging to the specified department ID' do
        expected_salaries = Salary.where(department: department)
        expect(Salary.by_department(department.id)).to match_array(expected_salaries)
      end

      it 'returns all salaries if department ID is nil or blank' do
        expect(Salary.by_department(nil).count).to eq(Salary.count)
      end
    end
  end

  describe 'Ransack configuration' do
    describe '.ransackable_attributes' do
      let(:ransackable_attrs) { Salary.ransackable_attributes }

      it 'includes necessary filtering attributes' do
        expect(ransackable_attrs).to include('amount', 'department_id', 'paid_on')
      end
    end

    describe '.ransackable_associations' do
      it 'includes department and employee' do
        expect(Salary.ransackable_associations).to match_array(%w[department employee])
      end
    end

    describe '.ransackable_scopes' do
      it 'includes all custom filtering scopes' do
        expected_scopes = %i[by_month by_year by_department]
        expect(Salary.ransackable_scopes).to match_array(expected_scopes)
      end
    end
  end
end
