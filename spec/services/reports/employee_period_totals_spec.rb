# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::EmployeePeriodTotals do
  let(:settings) { create(:tax_setting) }
  let(:employee) { create(:employee, children_count: 0, disability_group: 0, chaes: false) }

  let(:zero) do
    { gross_cents: 0, income_tax_cents: 0, military_tax_cents: 0, net_cents: 0 }
  end

  def totals_for(salary:, vacation: zero, sick: zero)
    described_class.call(salary: salary, vacation: vacation, sick: sick,
                         employee: employee, settings: settings)
  end

  it 'returns zero totals for empty incomes' do
    totals = totals_for(salary: zero)

    expect(totals).to include(gross_cents: 0, income_tax_cents: 0,
                              military_tax_cents: 0, net_amount_cents: 0)
  end

  it 'applies the social benefit below the income threshold' do
    totals = totals_for(salary: { gross_cents: 100_000, income_tax_cents: 0,
                                  military_tax_cents: 0, net_cents: 95_000 })

    expect(totals[:gross_cents]).to eq(100_000)
    expect(totals[:income_tax_cents]).to eq(0)
    expect(totals[:military_tax_cents]).to eq(5_000)
  end

  it 'taxes combined salary and vacation gross once, above the threshold' do
    totals = totals_for(
      salary: { gross_cents: 500_000, income_tax_cents: 0, military_tax_cents: 0, net_cents: 0 },
      vacation: { gross_cents: 100_000, income_tax_cents: 0, military_tax_cents: 0, net_cents: 0 }
    )

    expect(totals[:combined_gross_cents]).to eq(600_000)
    expect(totals[:gross_cents]).to eq(600_000)
    expect(totals[:income_tax_cents]).to eq(108_000)   # 6000 × 18%
    expect(totals[:military_tax_cents]).to eq(30_000)  # 6000 × 5%
    expect(totals[:net_amount_cents]).to eq(462_000)
  end

  it 'keeps the combined salary and vacation figures separate from sick leave' do
    totals = totals_for(
      salary: { gross_cents: 500_000, income_tax_cents: 0, military_tax_cents: 0, net_cents: 0 },
      vacation: { gross_cents: 100_000, income_tax_cents: 0, military_tax_cents: 0, net_cents: 0 },
      sick: { gross_cents: 80_000, income_tax_cents: 4_000, military_tax_cents: 400, net_cents: 75_600 }
    )

    expect(totals[:combined_gross_cents]).to eq(600_000)
    expect(totals[:combined_income_tax_cents]).to eq(108_000)
    expect(totals[:combined_military_tax_cents]).to eq(30_000)
    expect(totals[:gross_cents]).to eq(680_000)
    expect(totals[:income_tax_cents]).to eq(112_000)   # 108 000 + 4 000
    expect(totals[:military_tax_cents]).to eq(30_400)  # 30 000 + 400
    expect(totals[:net_amount_cents]).to eq(537_600)   # 462 000 + 75 600
  end

  it 'passes through the sign of the benefit applied by the tax calculation' do
    employee.update!(disability_group: 1)
    totals = totals_for(salary: { gross_cents: 100_000, income_tax_cents: 0,
                                  military_tax_cents: 0, net_cents: 95_000 })

    expect(totals[:psp_sign]).to eq('2')
  end
end
