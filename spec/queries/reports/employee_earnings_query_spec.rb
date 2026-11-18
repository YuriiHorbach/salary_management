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

    describe 'filters' do
      let(:petrenko) do
        create(:employee, id_code: '1234567890', last_name: 'Петренко',
                          first_name: 'Іван', patronic_name: 'Іванович')
      end
      let(:ivanenko) do
        create(:employee, id_code: '0987654321', last_name: 'Іваненко',
                          first_name: 'Марія', patronic_name: 'Петрівна')
      end

      before do
        create_salary(employee: petrenko, department: farm, position: milkmaid, amount_cents: 100_000)
        create_salary(employee: petrenko, department: farm, position: mechanic, amount_cents: 50_000)
        create_salary(employee: ivanenko, department: autopark, position: driver, amount_cents: 25_000)
      end

      it 'filters salaries and columns by department' do
        result = described_class.new(period: '2025-05', department: farm.id).call

        expect(result[:columns].map { |column| column[:label] })
          .to eq(['Ферма доярка', 'Ферма механік'])
        expect(result[:rows].map { |row| row[:id_code] }).to eq(['1234567890'])
        expect(result[:rows].first[:total_salary]).to eq(1500.0)
        expect(result[:totals][:salary]).to eq(1500.0)
      end

      it 'filters salaries and columns by position' do
        result = described_class.new(period: '2025-05', position: milkmaid.id).call

        expect(result[:columns].map { |column| column[:label] }).to eq(['Ферма доярка'])
        expect(result[:rows].first[:total_salary]).to eq(1000.0)
      end

      it 'filters by brigade' do
        brigade = create(:territory_sign, name: 'Бригада 1')
        petrenko.update!(territory_sign: brigade)

        result = described_class.new(period: '2025-05', brigade: brigade.id).call

        expect(result[:rows].map { |row| row[:id_code] }).to eq(['1234567890'])
      end

      it 'filters by account book code' do
        create(:account_book, employee: petrenko, code: 'Б77')

        result = described_class.new(period: '2025-05', account_book: 'Б77').call

        expect(result[:rows].map { |row| row[:id_code] }).to eq(['1234567890'])
      end

      it 'filters by employee search' do
        result = described_class.new(period: '2025-05', employee_search: 'Іваненко').call

        expect(result[:rows].map { |row| row[:id_code] }).to eq(['0987654321'])
      end

      it 'filters employees by the applied tax benefit code' do
        child = create(:employee, id_code: '5555555555', children_count: 2)
        create_salary(employee: child, department: farm, position: milkmaid, amount_cents: 200_000)

        result = described_class.new(period: '2025-05', benefit: '04').call

        expect(result[:rows].map { |row| row[:id_code] }).to eq(['5555555555'])
      end

      it 'filters employees without an applied benefit' do
        high_income = create(:employee, id_code: '6666666666')
        create_salary(employee: high_income, department: farm, position: mechanic, amount_cents: 500_000)

        result = described_class.new(period: '2025-05', benefit: 'none').call

        expect(result[:rows].map { |row| row[:id_code] }).to eq(['6666666666'])
      end

      it 'accepts string keys from request params' do
        result = described_class.new('period' => '2025-05', 'department' => farm.id.to_s).call

        expect(result[:rows].map { |row| row[:id_code] }).to eq(['1234567890'])
      end

      it 'filters salaries by a date range' do
        create(:salary, employee: ivanenko, department: autopark, position: driver,
                        amount_cents: 200_000, period: Date.new(2025, 6, 1),
                        paid_on: Date.new(2025, 6, 1))

        result = described_class.new(date_from: '2025-05-01', date_to: '2025-05-31').call

        expect(result[:period]).to eq(Date.new(2025, 5, 1))
        expect(result[:rows].to_h { |row| [row[:id_code], row[:total_salary]] })
          .to eq('1234567890' => 1500.0, '0987654321' => 250.0)
      end

      it 'lets an explicit period override the date range' do
        create(:salary, employee: ivanenko, department: autopark, position: driver,
                        amount_cents: 200_000, period: Date.new(2025, 6, 1),
                        paid_on: Date.new(2025, 6, 1))

        result = described_class.new(
          period: '2025-06', date_from: '2025-05-01', date_to: '2025-05-31'
        ).call

        expect(result[:rows].to_h { |row| [row[:id_code], row[:total_salary]] })
          .to eq('0987654321' => 2000.0)
      end
    end
  end
end
