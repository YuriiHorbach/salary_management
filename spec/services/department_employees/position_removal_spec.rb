# frozen_string_literal: true

require 'rails_helper'

# Verifies the rules for removing a single position assignment from one
# employee inside one department.
RSpec.describe DepartmentEmployees::PositionRemoval, type: :service do
  let(:department) { create(:department) }
  let(:other_department) { create(:department) }
  let(:employee) { create(:employee) }
  let(:manager_position) { create(:position, department: department, position_name: 'Manager') }
  let(:engineer_position) { create(:position, department: department, position_name: 'Engineer') }
  let(:foreign_position) { create(:position, department: other_department, position_name: 'Foreign') }

  before do
    create(:department_employee, employee: employee, department: department)
  end

  describe '.call' do
    it 'removes the requested position from the employee' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      result = described_class.call(department: department, employee: employee, position: manager_position)

      expect(result).to be(true)
      expect(assigned_position_ids).to contain_exactly(nil)
    end

    it 'keeps the other positions of the employee' do
      create(:department_employee, employee: employee, department: department, position: manager_position)
      create(:department_employee, employee: employee, department: department, position: engineer_position)

      described_class.call(department: department, employee: employee, position: manager_position)

      expect(assigned_position_ids).to contain_exactly(engineer_position.id)
    end

    it 'keeps the employee in the department when the last position is removed' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      described_class.call(department: department, employee: employee, position: manager_position)

      expect(department.employees).to include(employee)
      expect(department.department_employees.where(employee_id: employee.id).count).to eq(1)
      expect(assigned_position_ids).to eq([nil])
    end

    it 'does not touch assignments of other employees' do
      other_employee = create(:employee)
      other_assignment = create(
        :department_employee,
        employee: other_employee,
        department: department,
        position: manager_position
      )
      create(:department_employee, employee: employee, department: department, position: manager_position)

      described_class.call(department: department, employee: employee, position: manager_position)

      expect(other_assignment.reload.position).to eq(manager_position)
    end

    it 'does not remove assignments in other departments' do
      foreign_assignment = create(
        :department_employee,
        employee: employee,
        department: other_department,
        position: foreign_position
      )

      described_class.call(department: department, employee: employee, position: foreign_position)

      expect(foreign_assignment.reload.position).to eq(foreign_position)
    end

    it 'returns false when the position belongs to another department' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      result = described_class.call(department: department, employee: employee, position: foreign_position)

      expect(result).to be(false)
      expect(assigned_position_ids).to contain_exactly(nil, manager_position.id)
    end

    it 'returns false when the position is not assigned to the employee' do
      result = described_class.call(department: department, employee: employee, position: manager_position)

      expect(result).to be(false)
      expect(assigned_position_ids).to eq([nil])
    end

    it 'returns false and does not add membership for an outsider' do
      outsider = create(:employee)

      result = described_class.call(department: department, employee: outsider, position: manager_position)

      expect(result).to be(false)
      expect(department.department_employees.where(employee_id: outsider.id)).to be_empty
    end

    it 'returns false when no position is given' do
      result = described_class.call(department: department, employee: employee, position: nil)

      expect(result).to be(false)
    end
  end

  def assigned_position_ids
    department.department_employees.where(employee_id: employee.id).pluck(:position_id)
  end
end
