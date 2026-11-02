# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Salaries::PeriodIncomeTable do
  def income(period:, income_type:, gross: 0, income_tax: 0, military_tax: 0)
    EmployeePeriodIncome.new(
      period: period,
      income_type: income_type,
      gross_cents: gross,
      income_tax_cents: income_tax,
      military_tax_cents: military_tax
    )
  end

  let(:january) { Date.new(2026, 1, 1) }
  let(:february) { Date.new(2026, 2, 1) }

  describe '#call' do
    it 'returns no rows for an empty collection' do
      expect(described_class.new([]).call).to eq([])
    end

    it 'groups records by period and orders rows newest period first' do
      records = [
        income(period: january, income_type: 'salary'),
        income(period: february, income_type: 'salary')
      ]

      expect(described_class.new(records).call.map(&:period)).to eq([february, january])
    end

    it 'places each income type on its own field of the row' do
      salary = income(period: january, income_type: 'salary')
      vacation = income(period: january, income_type: 'vacation')
      sick = income(period: january, income_type: 'sick_day')

      row = described_class.new([vacation, sick, salary]).call.first

      expect(row.salary).to equal(salary)
      expect(row.vacation).to equal(vacation)
      expect(row.sick).to equal(sick)
    end

    it 'sums totals across income types in cents and treats missing types as zero' do
      salary = income(period: january, income_type: 'salary',
                      gross: 100_000, income_tax: 15_000, military_tax: 5_000)
      vacation = income(period: january, income_type: 'vacation',
                        gross: 40_000, income_tax: 6_000, military_tax: 2_000)

      row = described_class.new([salary, vacation]).call.first

      expect(row.gross_total).to eq(140_000)
      expect(row.income_tax_total).to eq(21_000)
      expect(row.military_tax_total).to eq(7_000)
      expect(row.sick).to be_nil
    end

    it 'produces one row per period even when only one income type exists' do
      records = [
        income(period: january, income_type: 'salary'),
        income(period: january, income_type: 'salary'),
        income(period: february, income_type: 'vacation')
      ]

      expect(described_class.new(records).call.size).to eq(2)
    end
  end
end
