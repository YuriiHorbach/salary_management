# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DepartmentEmployee, type: :model do
  describe 'validations' do
		let(:employee) { create(:employee) }
		let(:department) { create(:department) }

    it 'do not allow add the same employee to one department' do
      create(:department_employee, employee: employee, department: department)

      duplicate = build(:department_employee, employee: employee, department: department)

      expect(duplicate.valid?).to eq(false)
      expect(duplicate.errors[:employee_id]).to include('employee alredy exists in this department')
    end

    it 'allows adding the same employee to a different department' do
      create(:department_employee, employee: employee, department: department)
      
      other_department = create(:department)
      new_assignment = build(:department_employee, employee: employee, department: other_department)

      expect(new_assignment.valid?).to eq(true)
    end

    it 'allows adding different employees to the same department' do
      create(:department_employee, employee: employee, department: department)
      
      new_employee = create(:employee)
      new_assignment = build(:department_employee, employee: new_employee, department: department)

      expect(new_assignment.valid?).to eq(true)
    end

    it 'is invalid without an employee' do
      invalid_assignment = build(:department_employee, employee: nil, department: department)

      expect(invalid_assignment).not_to be_valid
      expect(invalid_assignment.errors[:employee]).to include('must exist')
    end
  end
end
