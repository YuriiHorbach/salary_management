# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Employee, type: :model do
  describe 'validations' do
    it 'is valid with an id_code' do
      employee = build(:employee, id_code: 1_111_111_111)

      expect(employee).to be_valid
    end

    it 'is invalid when id_code length less then 10 numbers' do
      employee = build(:employee, id_code: 1_111_111_11)

      expect(employee).to be_invalid
    end

    it 'is valid with a first_name' do
      employee = build(:employee, first_name: 'John')

      expect(employee).to be_valid
    end

    it 'is invalid without a first_name' do
      employee = build(:employee, first_name: '')

      expect(employee).to be_invalid
    end

    it 'is valid with a patronic_name' do
      employee = build(:employee, patronic_name: 'Testovich')

      expect(employee).to be_valid
    end

    it 'is invalid withot a patronic_name' do
      employee = build(:employee, patronic_name: '')

      expect(employee).to be_invalid
    end

    it 'is valid with a last_name' do
      employee = build(:employee, patronic_name: 'Testovii')

      expect(employee).to be_valid
    end

    it 'is invalid without a last_name' do
      employee = build(:employee, patronic_name: '')

      expect(employee).to be_invalid
    end

    # it 'is invalid if total salary is negative' do
    #   employee = build(:employee, total_salary: -100)
    #   expect(employee).not_to be_valid
    # end
  end

  describe '#total_salary' do
    let(:employee) { create(:employee) }

    it 'returns sum of all salaries' do
      create(:salary, employee: employee, amount: 100_000)
      create(:salary, employee: employee, amount: 200_000)

      expect(employee.total_salary).to eq(300_000)
    end

    it 'returns 0 when employee has no salaries' do
      expect(employee.total_salary).to eq(0)
    end

    it 'calculates total_salary dynamically' do
      create(:salary, employee: employee, amount: 50_000)
      expect(employee.total_salary).to eq(50_000)

      create(:salary, employee: employee, amount: 50_000)
      expect(employee.total_salary).to eq(100_000)
    end
  end

  describe "after change employee setup and save" do
    let!(:employee) { create(:employee, children_count: 0) }
    let!(:salary) { create(:salary, employee: employee, created_at: 1.hour.ago) }

    it "automatically recalculate taxes after changing children amount" do
      old_tax = salary.income_tax_cents
      
      employee.update!(children_count: 3)
      
      expect(salary.reload.income_tax_cents).not_to eq(old_tax)
    end
  end
end
