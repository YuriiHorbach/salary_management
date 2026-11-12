# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vacation, type: :model do
  let(:employee) { create(:employee) }
  let(:vacation) { build(:vacation, employee: employee, period: '2023-01-01', vacation_amount_cents: 100_000) }

  describe 'callbacks' do
    it 'automatically calculates taxes before validation' do
      vacation.valid?
      expect(vacation.income_tax_cents).to eq(18_000)
      expect(vacation.military_tax_cents).to eq(5_000)
      expect(vacation.net_amount_cents).to eq(77_000)
    end
  end

  describe '#pdfo_amount' do
    it 'calculates the correct PDFO amount' do
      vacation.valid?
      expect(vacation.pdfo_amount).to eq(Money.new(18_000, 'USD'))
    end
  end

  describe '#military_amount' do
    it 'calculates the correct military amount' do
      vacation.valid?
      expect(vacation.military_amount).to eq(Money.new(5_000, 'USD'))
    end
  end

  describe '.report_for_month' do
    it 'returns per-employee vacation counts for the requested month' do
      first_employee = create(:employee)
      second_employee = create(:employee)
      create_list(:vacation, 2, employee: first_employee, period: Date.new(2026, 3, 1))
      create(:vacation, employee: second_employee, period: Date.new(2026, 3, 1))
      create(:vacation, employee: first_employee, period: Date.new(2026, 4, 1))

      counts = described_class.report_for_month('2026-03')

      expect(counts).to eq(first_employee.id => 2, second_employee.id => 1)
    end

    it 'returns an empty hash for a malformed or blank month' do
      expect(described_class.report_for_month('not-a-month')).to eq({})
      expect(described_class.report_for_month(nil)).to eq({})
    end
  end

  describe '.report_rows_for_month' do
    let(:first_employee) { create(:employee) }
    let(:second_employee) { create(:employee) }

    before do
      create_vacation(first_employee, 30_000)
      create_vacation(first_employee, 70_000)
      create_vacation(second_employee, 10_000)
    end

    it 'returns per-employee counts and monetary totals for the requested month' do
      rows = described_class.report_rows_for_month('2026-03')

      expect(rows.find { |row| row.employee_id == first_employee.id }).to have_attributes(
        vacations_count: 2, vacation_cents: 100_000, income_tax_cents: 18_000,
        military_tax_cents: 5_000, net_cents: 77_000
      )
      expect(rows.find { |row| row.employee_id == second_employee.id }).to have_attributes(
        vacations_count: 1, vacation_cents: 10_000, income_tax_cents: 1_800,
        military_tax_cents: 500, net_cents: 7_700
      )
    end

    it 'returns an empty array for a malformed or blank month' do
      expect(described_class.report_rows_for_month('not-a-month')).to eq([])
      expect(described_class.report_rows_for_month(nil)).to eq([])
    end

    def create_vacation(employee, amount_cents)
      create(:vacation, employee: employee, period: Date.new(2026, 3, 1),
                        vacation_amount_cents: amount_cents)
    end
  end
end
