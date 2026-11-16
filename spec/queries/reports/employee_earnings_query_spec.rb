# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::EmployeeEarningsQuery do
  let(:period) { Date.new(2025, 5, 1) }
  let(:farm) { create(:department, name: 'Ферма') }
  let(:autopark) { create(:department, name: 'Автопарк') }
  let(:milkmaid) { create(:position, department: farm, position_name: 'доярка') }
  let(:mechanic) { create(:position, department: farm, position_name: 'механік') }
  let(:driver) { create(:position, department: autopark, position_name: 'водій') }

  def create_salary(employee:, department:, amount_cents:, position: nil, on: period)
    create(:department_employee, employee: employee, department: department, position: position) if position

    create(:salary, employee: employee, department: department, position: position,
                    amount_cents: amount_cents, period: on, paid_on: on)
  end

  describe '#call' do
    it 'returns an empty result when there are no salaries in the period' do
      result = described_class.new(period: '2025-05').call

      expect(result[:columns]).to eq([])
      expect(result[:rows]).to eq([])
      expect(result[:totals][:salary]).to eq(0.0)
    end

    it 'defaults to the current month when no period is given' do
      expect(described_class.new.call[:period]).to eq(Date.current.beginning_of_month)
    end

    context 'when an employee holds several positions' do
      let(:employee) do
        create(:employee, id_code: '1234567890', last_name: 'Петренко',
                          first_name: 'Іван', patronic_name: 'Іванович')
      end

      before do
        create_salary(employee: employee, department: farm, position: milkmaid, amount_cents: 100_000)
        create_salary(employee: employee, department: farm, position: mechanic, amount_cents: 50_000)
        create_salary(employee: employee, department: autopark, position: driver, amount_cents: 25_000)
      end

      it 'returns one row per employee with a dynamic column per department and position' do
        result = described_class.new(period: '2025-05').call
        row = result[:rows].first

        expect(result[:columns].map { |column| column[:label] }).to eq(
          ['Автопарк водій', 'Ферма доярка', 'Ферма механік']
        )
        expect(row.values_at(:id_code, :full_name, :total_salary))
          .to eq(['1234567890', 'Петренко Іван Іванович', 1750.0])
        expect(row[:earnings]).to eq(
          %w[Автопарк водій] => 250.0,
          %w[Ферма доярка] => 1000.0,
          %w[Ферма механік] => 500.0
        )
      end
    end

    it 'sorts employee rows by full name' do
      andriienko = create(:employee, last_name: 'Андрієнко', first_name: 'Олег')
      yaremenko = create(:employee, last_name: 'Яременко', first_name: 'Іван')
      create_salary(employee: yaremenko, department: farm, position: milkmaid, amount_cents: 10_000)
      create_salary(employee: andriienko, department: farm, position: mechanic, amount_cents: 20_000)
      create_salary(employee: andriienko, department: autopark, position: driver, amount_cents: 30_000)

      rows = described_class.new(period: '2025-05').call[:rows]

      expect(rows.map { |row| row[:full_name] }).to eq(
        ['Андрієнко Олег Testovich', 'Яременко Іван Testovich']
      )
    end

    it 'adds a department-only column for salaries without a position' do
      employee = create(:employee)
      create_salary(employee: employee, department: farm, amount_cents: 100_000)

      result = described_class.new(period: '2025-05').call
      column = result[:columns].first
      row = result[:rows].first

      expect(column.values_at(:department_name, :position_name, :label)).to eq(['Ферма', '', 'Ферма'])
      expect(row[:earnings][['Ферма', '']]).to eq(1000.0)
      expect(row[:total_salary]).to eq(1000.0)
    end

    it 'excludes salaries outside the selected period' do
      employee = create(:employee)
      create_salary(employee: employee, department: farm, amount_cents: 100_000)
      create_salary(employee: employee, department: autopark, position: driver,
                    amount_cents: 999_000, on: Date.new(2025, 6, 1))

      result = described_class.new(period: '2025-05').call

      expect(result[:columns].map { |column| column[:label] }).to eq(['Ферма'])
      expect(result[:rows].size).to eq(1)
      expect(result[:rows].first[:total_salary]).to eq(1000.0)
    end

    it 'computes the grand total and each employee total across all departments' do
      first = create(:employee)
      second = create(:employee)
      create_salary(employee: first, department: farm, position: milkmaid, amount_cents: 100_000)
      create_salary(employee: first, department: farm, position: mechanic, amount_cents: 50_000)
      create_salary(employee: second, department: autopark, position: driver, amount_cents: 25_000)

      result = described_class.new(period: '2025-05').call
      totals_by_employee = result[:rows].to_h { |row| [row[:employee_id], row[:total_salary]] }

      expect(totals_by_employee).to eq(first.id => 1500.0, second.id => 250.0)
      expect(result[:totals][:salary]).to eq(1750.0)
    end

    it 'groups salaries without a department under a fallback column' do
      employee = create(:employee)
      create_salary(employee: employee, department: nil, amount_cents: 100_000)

      result = described_class.new(period: '2025-05').call
      column = result[:columns].first
      row = result[:rows].first

      expect(column.values_at(:department_name, :position_name))
        .to eq([described_class::UNASSIGNED_DEPARTMENT, ''])
      expect(row[:earnings][[described_class::UNASSIGNED_DEPARTMENT, '']]).to eq(1000.0)
    end

    it 'ignores an invalid period and falls back to the current month' do
      expect(described_class.new(period: 'not-a-month').call[:period])
        .to eq(Date.current.beginning_of_month)
    end
  end
end
