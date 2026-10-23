# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Salary, type: :model do
  let(:employee) { create(:employee) }
  let(:department) { create(:department, name: 'Test Dept') }
  let(:salary) do
    create(:salary, employee: employee, department: department, amount_cents: 1000, paid_on: Date.new(2025, 5, 15))
  end

  let!(:salary_jan_dev) do
    create(:salary, department: department, paid_on: Date.new(2025, 1, 1), amount_cents: 100)
  end
  let!(:salary_feb_other) do
    create(:salary, department: create(:department, name: 'Other'), paid_on: Date.new(2025, 2, 1), amount_cents: 200)
  end
  let!(:salary_2024) do
    create(:salary, department: department, paid_on: Date.new(2024, 5, 1), amount_cents: 300)
  end

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:department).optional }
    it { should belong_to(:position).optional }
  end

  describe 'period' do
    it { should validate_presence_of(:period) }

    it 'derives the period from paid_on when it is not provided' do
      record = build(:salary, employee: employee, paid_on: Date.new(2025, 5, 15), period: nil)

      record.valid?

      expect(record.period).to eq(Date.new(2025, 5, 1))
    end

    it 'normalizes the period to the beginning of its month' do
      record = build(:salary, employee: employee, period: Date.new(2025, 5, 15))

      record.valid?

      expect(record.period).to eq(Date.new(2025, 5, 1))
    end

    it 'accepts a YYYY-MM string period from the month input' do
      record = build(:salary, employee: employee, period: '2025-05')

      record.valid?

      expect(record.period).to eq(Date.new(2025, 5, 1))
    end

    it 'allows only one salary without a position per employee, period and department' do
      create(:salary, employee: employee, department: department, period: Date.new(2025, 5, 1))

      duplicate = build(:salary, employee: employee, department: department, period: Date.new(2025, 5, 20))

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:period]).to include('already has a salary for this position/department in this period')
    end

    it 'allows salaries in different departments for the same employee and period' do
      create(:salary, employee: employee, department: department, period: Date.new(2025, 5, 1))

      other_department_salary = build(:salary, employee: employee, department: create(:department),
                                               period: Date.new(2025, 5, 1))

      expect(other_department_salary).to be_valid
    end

    it 'allows only one salary per position for the same employee and period' do
      position = create(:position, department: department)
      create(:department_employee, employee: employee, department: department, position: position)
      create(:salary, employee: employee, department: department, position: position,
                      period: Date.new(2025, 5, 1))

      duplicate = build(:salary, employee: employee, department: department, position: position,
                                 period: Date.new(2025, 5, 20))

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:period]).to include('already has a salary for this position/department in this period')
    end

    it 'allows different positions in the same department for the same period' do
      first_position = create(:position, department: department)
      second_position = create(:position, department: department)
      create(:department_employee, employee: employee, department: department, position: first_position)
      create(:department_employee, employee: employee, department: department, position: second_position)
      create(:salary, employee: employee, department: department, position: first_position,
                      period: Date.new(2025, 5, 1))

      second_salary = build(:salary, employee: employee, department: department, position: second_position,
                                     period: Date.new(2025, 5, 1))

      expect(second_salary).to be_valid
    end

    it 'rejects a position that belongs to another department' do
      other_position = create(:position, department: create(:department))
      create(:department_employee, employee: employee, department: department, position: other_position)

      record = build(:salary, employee: employee, department: department, position: other_position,
                              period: Date.new(2025, 5, 1))

      expect(record).not_to be_valid
      expect(record.errors[:position]).to include('belongs to another department')
    end

    it 'rejects a position that is not assigned to the employee' do
      position = create(:position, department: department)

      record = build(:salary, employee: employee, department: department, position: position,
                              period: Date.new(2025, 5, 1))

      expect(record).not_to be_valid
      expect(record.errors[:position]).to include('is not assigned to this employee')
    end

    it 'allows the same period for another employee' do
      create(:salary, employee: employee, period: Date.new(2025, 5, 1))

      other_salary = build(:salary, employee: create(:employee), period: Date.new(2025, 5, 1))

      expect(other_salary).to be_valid
    end

    it 'allows another period for the same employee' do
      create(:salary, employee: employee, period: Date.new(2025, 5, 1))

      next_salary = build(:salary, employee: employee, period: Date.new(2025, 6, 1))

      expect(next_salary).to be_valid
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
      create(:salary, employee: employee, amount_cents: 200, paid_on: Date.new(2025, 5, 1))
      create(:salary, employee: employee, amount_cents: 300, paid_on: Date.new(2025, 6, 1))
      result = Salary.monthly_sum_for_employee(employee.id)
      expect(result.values.sum).to eq(employee.salaries.sum(:amount_cents) / 100.0)
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
end
