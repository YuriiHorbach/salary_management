# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DepartmentEmployeePositionsQuery do
  let(:department) { create(:department) }
  let(:employee) { create(:employee) }
  let(:manager) { create(:position, department: department, position_name: 'Manager') }
  let(:engineer) { create(:position, department: department, position_name: 'Engineer') }

  def call(period_salaries: {}, position: nil)
    described_class.new(
      department,
      employee_ids: [employee.id],
      period_salaries: period_salaries,
      position: position
    ).call
  end

  it 'returns positions assigned to the employee sorted by name' do
    create(:department_employee, employee: employee, department: department, position: manager)
    create(:department_employee, employee: employee, department: department, position: engineer)

    expect(call.fetch(employee.id)).to eq([engineer, manager])
  end

  it 'adds positions referenced only by salaries' do
    create(:department_employee, employee: employee, department: department, position: engineer)

    result = call(period_salaries: { [employee.id, manager.id] => 100_000 })

    expect(result.fetch(employee.id)).to eq([engineer, manager])
  end

  it 'limits assignments and salary positions to the selected position' do
    create(:department_employee, employee: employee, department: department, position: manager)
    create(:department_employee, employee: employee, department: department, position: engineer)

    result = call(
      period_salaries: { [employee.id, engineer.id] => 100_000 },
      position: engineer.id
    )

    expect(result.fetch(employee.id)).to eq([engineer])
  end

  it 'filters salary-only positions when several salary keys are present' do
    result = call(
      period_salaries: {
        [employee.id, manager.id] => 100_000,
        [employee.id, engineer.id] => 50_000
      },
      position: engineer.id
    )

    expect(result.fetch(employee.id)).to eq([engineer])
  end

  it 'accepts a Position object as the filter' do
    create(:department_employee, employee: employee, department: department, position: manager)

    result = call(position: manager)

    expect(result.fetch(employee.id)).to eq([manager])
  end

  it 'ignores salaries belonging to employees outside the requested ids' do
    other_employee = create(:employee)

    result = call(period_salaries: { [other_employee.id, manager.id] => 100_000 })

    expect(result).to be_empty
  end
end
