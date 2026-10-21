# frozen_string_literal: true

require 'rails_helper'

# Covers aggregation of all amounts of one income type for one employee and one
# period, followed by a single tax calculation on the total gross.
RSpec.describe Incomes::PeriodRecalculator, type: :service do
  let(:employee) do
    create(:employee, children_count: 0, disability_group: 0, chaes: false, contract: false)
  end
  let(:department) { create(:department) }
  let(:other_department) { create(:department) }
  let(:period) { Date.new(2026, 5, 1) }

  describe 'salary income' do
    it 'calculates taxes on the total gross of every salary in the period' do
      create(:salary, employee: employee, department: department, period: period, paid_on: period,
                      amount_cents: 100_000)
      create(:salary, employee: employee, department: other_department, period: period, paid_on: period,
                      amount_cents: 200_000)

      described_class.call(employee: employee, period: period, income_type: 'salary')

      aggregate = aggregate_for('salary')
      expected = TaxCalculator.call(amount_cents: 300_000, children_count: 0, disability_group: 0,
                                    chaes: false, contract: false)

      expect(aggregate.gross_cents).to eq(300_000)
      expect(aggregate.income_tax_cents).to eq(expected[:income_tax_cents])
      expect(aggregate.military_tax_cents).to eq(expected[:military_tax_cents])
      expect(aggregate.net_amount_cents).to eq(expected[:net_amount_cents])
      expect(aggregate.tax_settings_digest).to be_present
    end

    it 'does not mix salaries from another period' do
      create(:salary, employee: employee, department: department, period: period, paid_on: period,
                      amount_cents: 100_000)
      create(:salary, employee: employee, department: department, period: period.next_month,
                      paid_on: period.next_month, amount_cents: 900_000)

      described_class.call(employee: employee, period: period, income_type: 'salary')

      expect(aggregate_for('salary').gross_cents).to eq(100_000)
    end

    it 'rebuilds the aggregate when a salary amount changes' do
      salary = create(:salary, employee: employee, department: department, period: period,
                               paid_on: period, amount_cents: 100_000)

      described_class.call(employee: employee, period: period, income_type: 'salary')
      salary.update!(amount_cents: 250_000)
      described_class.call(employee: employee, period: period, income_type: 'salary')

      expect(aggregate_for('salary').gross_cents).to eq(250_000)
    end

    it 'removes the aggregate when the period has no salaries left' do
      salary = create(:salary, employee: employee, department: department, period: period,
                               paid_on: period, amount_cents: 100_000)
      described_class.call(employee: employee, period: period, income_type: 'salary')

      salary.destroy!
      described_class.call(employee: employee, period: period, income_type: 'salary')

      expect(EmployeePeriodIncome.where(employee: employee, period: period, income_type: 'salary')).to be_empty
    end
  end

  describe 'vacation income' do
    it 'calculates taxes once on the total of all vacations in the period' do
      create(:vacation, employee: employee, period: period, vacation_amount_cents: 100_000)
      create(:vacation, employee: employee, period: period, vacation_amount_cents: 50_000)

      described_class.call(employee: employee, period: period, income_type: 'vacation')

      aggregate = aggregate_for('vacation')
      expected = TaxCalculator.call(amount_cents: 150_000, simple: true)

      expect(aggregate.gross_cents).to eq(150_000)
      expect(aggregate.income_tax_cents).to eq(expected[:income_tax_cents])
      expect(aggregate.military_tax_cents).to eq(expected[:military_tax_cents])
    end
  end

  describe 'sick day income' do
    it 'calculates taxes once on the total pfu and enterprise amounts in the period' do
      create(:sick_day, employee: employee, period: period,
                        pfu_amount_cents: 100_000, enterprise_amount_cents: 50_000)
      create(:sick_day, employee: employee, period: period,
                        pfu_amount_cents: 20_000, enterprise_amount_cents: 10_000)

      described_class.call(employee: employee, period: period, income_type: 'sick_day')

      aggregate = aggregate_for('sick_day')
      expected = TaxCalculator.call(amount_cents: 180_000, simple: true)

      expect(aggregate.gross_cents).to eq(180_000)
      expect(aggregate.income_tax_cents).to eq(expected[:income_tax_cents])
      expect(aggregate.military_tax_cents).to eq(expected[:military_tax_cents])
      expect(aggregate.net_amount_cents).to eq(expected[:net_amount_cents])
    end
  end

  def aggregate_for(income_type)
    EmployeePeriodIncome.find_by!(employee_id: employee.id, period: period, income_type: income_type)
  end
end
