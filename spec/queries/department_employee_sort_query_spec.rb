# frozen_string_literal: true

require 'rails_helper'

# Covers custom department employee ordering for columns that cannot use a
# plain Ransack sort: the displayed position name and the selected-period salary
# total.
RSpec.describe DepartmentEmployeeSortQuery do
  let(:alpha) { build_stubbed(:employee, id: 1, last_name: 'Alpha', first_name: 'Anna') }
  let(:zeta) { build_stubbed(:employee, id: 2, last_name: 'Zeta', first_name: 'Zoe') }
  let(:employees) { [alpha, zeta] }
  let(:engineer) { build_stubbed(:position, position_name: 'Engineer') }
  let(:manager) { build_stubbed(:position, position_name: 'Manager') }
  let(:positions_by_employee) do
    {
      alpha.id => [manager],
      zeta.id => [engineer]
    }
  end
  let(:salary_totals) do
    {
      alpha.id => 100_000,
      zeta.id => 50_000
    }
  end

  def sort(sort_value, totals: salary_totals, positions: positions_by_employee)
    described_class.new(
      employees,
      sort: sort_value,
      positions_by_employee: positions,
      salary_totals: totals
    ).call
  end

  it 'sorts by the displayed position name ascending' do
    expect(sort('position asc')).to eq([zeta, alpha])
  end

  it 'sorts by the displayed position name descending' do
    expect(sort('position desc')).to eq([alpha, zeta])
  end

  it 'sorts by salary total ascending' do
    expect(sort('salary asc')).to eq([zeta, alpha])
  end

  it 'sorts by salary total descending' do
    expect(sort('salary desc')).to eq([alpha, zeta])
  end

  it 'uses the employee name as a stable tie-breaker' do
    equal_totals = { alpha.id => 50_000, zeta.id => 50_000 }

    expect(sort('salary asc', totals: equal_totals)).to eq([alpha, zeta])
  end

  it 'leaves the original order untouched for an unsupported sort' do
    expect(sort('last_name desc')).to eq(employees)
  end
end
