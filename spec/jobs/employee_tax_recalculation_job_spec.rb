# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeTaxRecalculationJob do
  let(:employee) { create(:employee) }
  let(:period) { Date.current.beginning_of_month }
  let!(:salary) do
    create(:salary, employee: employee, amount_cents: 700_000, period: period, paid_on: period)
  end

  def expected_taxes
    TaxCalculator.call(
      amount_cents: salary.amount_cents,
      children_count: employee.children_count.to_i,
      disability_group: employee.disability_group.to_i,
      chaes: employee.chaes || false,
      contract: employee.contract || false
    )
  end

  it 'refreshes the salary tax columns and the period aggregate' do
    described_class.perform_now(employee.id, period)

    expect(salary.reload).to have_attributes(
      income_tax_cents: expected_taxes[:income_tax_cents],
      military_tax_cents: expected_taxes[:military_tax_cents],
      net_amount_cents: expected_taxes[:net_amount_cents]
    )

    aggregate = EmployeePeriodIncome.find_by(employee: employee, period: period, income_type: 'salary')
    expect(aggregate.gross_cents).to eq(salary.amount_cents)
  end

  it 'recalculates every salary of the employee in the period' do
    other_department = create(:department)
    other_salary = create(:salary, employee: employee, department: other_department,
                                   amount_cents: 300_000, period: period, paid_on: period,
                                   income_tax_cents: 0, military_tax_cents: 0, net_amount_cents: 0)

    described_class.perform_now(employee.id, period)

    expect(other_salary.reload.income_tax_cents).to be_positive
  end

  it 'ignores salaries from other periods' do
    old_period = period - 1.month
    old_salary = create(:salary, employee: employee, amount_cents: 300_000,
                                 period: old_period, paid_on: old_period,
                                 income_tax_cents: 0, military_tax_cents: 0, net_amount_cents: 0)

    described_class.perform_now(employee.id, period)

    expect(old_salary.reload.income_tax_cents).to eq(0)
  end

  it 'does nothing when the employee no longer exists' do
    expect { described_class.perform_now(-1, period) }.not_to raise_error
  end
end
