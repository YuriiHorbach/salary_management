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

    it 'is valid with a positive total salary' do
      employee = build(:employee, total_salary: 1000)
      expect(employee).to be_valid
    end

    it 'is valid with a zero total salary' do
      employee = build(:employee, total_salary: 0)
      expect(employee).to be_valid
    end

    it 'is invalid if total salary is negative' do
      employee = build(:employee, total_salary: -100)
      expect(employee).not_to be_valid
    end
  end
end
