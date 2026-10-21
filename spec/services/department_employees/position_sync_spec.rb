# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DepartmentEmployees::PositionSync, type: :service do
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
    it 'assigns the selected positions to the employee' do
      result = described_class.call(
        department: department,
        employee: employee,
        position_ids: [manager_position.id, engineer_position.id]
      )

      expect(result).to be(true)
      expect(assigned_position_ids).to contain_exactly(manager_position.id, engineer_position.id)
    end

    it 'replaces the current positions with the selected ones' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      described_class.call(
        department: department,
        employee: employee,
        position_ids: [engineer_position.id]
      )

      expect(assigned_position_ids).to contain_exactly(engineer_position.id)
    end

    it 'does not duplicate an already assigned position' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      described_class.call(
        department: department,
        employee: employee,
        position_ids: [manager_position.id, manager_position.id.to_s]
      )

      expect(department.department_employees.where(employee_id: employee.id, position: manager_position).count).to eq(1)
    end

    it 'ignores positions that belong to another department' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      described_class.call(
        department: department,
        employee: employee,
        position_ids: [manager_position.id, foreign_position.id]
      )

      expect(assigned_position_ids).to contain_exactly(manager_position.id)
    end

    it 'keeps existing positions when every requested position is foreign' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      result = described_class.call(
        department: department,
        employee: employee,
        position_ids: [foreign_position.id]
      )

      expect(result).to be(false)
      expect(assigned_position_ids).to contain_exactly(nil, manager_position.id)
    end

    it 'keeps the employee in the department when all positions are cleared' do
      create(:department_employee, employee: employee, department: department, position: manager_position)

      described_class.call(department: department, employee: employee, position_ids: [])

      assignments = department.department_employees.where(employee_id: employee.id)

      expect(assignments.count).to eq(1)
      expect(assignments.first.position_id).to be_nil
      expect(department.employees).to include(employee)
    end

    it 'creates a positionless membership when positions are cleared for the first time' do
      described_class.call(department: department, employee: employee, position_ids: [])

      expect(assigned_position_ids).to eq([nil])
    end

    it 'does not change assignments of other employees' do
      other_employee = create(:employee)
      other_assignment = create(
        :department_employee,
        employee: other_employee,
        department: department,
        position: manager_position
      )

      described_class.call(department: department, employee: employee, position_ids: [engineer_position.id])

      expect(other_assignment.reload.position).to eq(manager_position)
    end

    it 'does not change assignments in other departments' do
      foreign_assignment = create(
        :department_employee,
        employee: employee,
        department: other_department,
        position: foreign_position
      )

      described_class.call(department: department, employee: employee, position_ids: [engineer_position.id])

      expect(foreign_assignment.reload.position).to eq(foreign_position)
    end
  end

  def assigned_position_ids
    department.department_employees.where(employee_id: employee.id).pluck(:position_id)
  end
end
