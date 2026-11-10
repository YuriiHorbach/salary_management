# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::FourDfQuery do
  let(:settings) { create(:tax_setting) } # 18% / 5%, ПСП 1664 ₴, граничний дохід 4660 ₴

  before do
    settings # make the singleton exist before any calculation
  end

  def income(employee, type:, period:, gross:, income_tax: 0, military_tax: 0, net: 0)
    create(:employee_period_income, employee: employee, income_type: type,
                                    period: period, gross_cents: gross,
                                    income_tax_cents: income_tax,
                                    military_tax_cents: military_tax,
                                    net_amount_cents: net)
  end

  it 'returns no rows when nobody has period income' do
    expect(described_class.new.call).to eq([])
  end

  it 'builds one row per employee from the detailed report totals' do
    employee = create(:employee, id_code: '1234567890', children_count: 0,
                                 disability_group: 0, chaes: false)
    # 5000 ₴ salary (above the 4660 ₴ threshold → 18% / 5%) plus 800 ₴ sick
    # leave with its own stored flat-rate taxes.
    income(employee, type: 'salary', period: Date.new(2026, 3, 1), gross: 500_000)
    income(employee, type: 'sick_day', period: Date.new(2026, 3, 1),
                     gross: 80_000, income_tax: 4_000, military_tax: 400, net: 75_600)

    rows = described_class.new.call

    expect(rows.size).to eq(1)
    expect(rows.first.tin).to eq('1234567890')
    expect(rows.first.gross_cents).to eq(580_000)
    expect(rows.first.income_tax_cents).to eq(94_000) # 90 000 + 4 000
    expect(rows.first.military_tax_cents).to eq(25_400) # 25 000 + 400
  end

  it 'matches the totals the detailed report shows for the same period' do
    employee = create(:employee, id_code: '2222222222', children_count: 0,
                                 disability_group: 0, chaes: false)
    create(:department_employee, employee: employee, department: create(:department))
    income(employee, type: 'salary', period: Date.new(2026, 3, 1), gross: 500_000)
    income(employee, type: 'vacation', period: Date.new(2026, 3, 1), gross: 100_000)
    income(employee, type: 'sick_day', period: Date.new(2026, 3, 1),
                     gross: 80_000, income_tax: 4_000, military_tax: 400, net: 75_600)

    detailed = Reports::EmployeeDetailedQuery.new(
      date_from: '2026-03-01', date_to: '2026-03-31'
    ).call[:employees].first
    row = described_class.new(year: '2026', month: '3').call.first

    expect(row.gross_cents).to eq((detailed[:total_income] * 100).round)
    expect(row.income_tax_cents).to eq((detailed[:total_tax] * 100).round)
    expect(row.military_tax_cents).to eq((detailed[:total_military] * 100).round)
  end

  it 'aggregates separately per employee and orders rows by last name' do
    # Names start with letters that sort identically in the Ukrainian alphabet
    # and in the database codepoint collation (А < Б).
    babyn = create(:employee, id_code: '1111111111', last_name: 'Бабін')
    abrikov = create(:employee, id_code: '2222222222', last_name: 'Абріков')
    income(babyn, type: 'salary', period: Date.new(2026, 3, 1), gross: 100_000)
    income(abrikov, type: 'salary', period: Date.new(2026, 3, 1), gross: 200_000)

    rows = described_class.new.call

    expect(rows.map(&:tin)).to eq(%w[2222222222 1111111111])
    expect(rows.map(&:gross_cents)).to eq([200_000, 100_000])
  end

  it 'filters income periods by year and month' do
    employee = create(:employee, id_code: '3333333333')
    income(employee, type: 'salary', period: Date.new(2026, 3, 1), gross: 100_000)
    income(employee, type: 'salary', period: Date.new(2026, 4, 1), gross: 900_000)
    income(employee, type: 'salary', period: Date.new(2025, 3, 1), gross: 55_000)

    march = described_class.new(year: '2026', month: '3').call
    expect(march.map(&:gross_cents)).to eq([100_000])

    full_year = described_class.new(year: '2026').call
    expect(full_year.map(&:gross_cents)).to eq([1_000_000])

    # A month without a year matches that month in every year, exactly like
    # the by_month scope of the general report.
    march_any_year = described_class.new(month: '3').call
    expect(march_any_year.map(&:gross_cents)).to eq([155_000])
  end

  it 'filters by a YYYY-MM period and lets it override year and month' do
    employee = create(:employee, id_code: '3333333333')
    income(employee, type: 'salary', period: Date.new(2026, 3, 1), gross: 100_000)
    income(employee, type: 'salary', period: Date.new(2026, 4, 1), gross: 900_000)

    rows = described_class.new(period: '2026-03', year: '2026', month: '4').call

    expect(rows.map(&:gross_cents)).to eq([100_000])
  end

  it 'scopes employees by department like the detailed report' do
    wanted = create(:employee, id_code: '4444444444')
    other = create(:employee, id_code: '5555555555')
    department = create(:department)
    create(:department_employee, employee: wanted, department: department)
    income(wanted, type: 'salary', period: Date.new(2026, 3, 1), gross: 100_000)
    income(other, type: 'salary', period: Date.new(2026, 3, 1), gross: 900_000)

    rows = described_class.new(department: department.id).call

    expect(rows.map(&:tin)).to eq(['4444444444'])
  end

  it 'skips employees whose totals are all zero' do
    employee = create(:employee, id_code: '6666666666')
    income(employee, type: 'salary', period: Date.new(2026, 3, 1), gross: 0)

    expect(described_class.new.call).to eq([])
  end

  describe 'OZN_PILG benefit sign' do
    def pilg_for(gross: 100_000, **attributes)
      employee = create(:employee, **attributes)
      income(employee, type: 'salary', period: Date.new(2026, 3, 1), gross: gross)

      described_class.new.call.first.pilg
    end

    it 'is 2 for an employee with a disability group' do
      expect(pilg_for(disability_group: 2)).to eq('2')
    end

    it 'is 2 for a Chernobyl liquidator' do
      expect(pilg_for(chaes: true)).to eq('2')
    end

    it 'is 4 for an employee with two or more children' do
      expect(pilg_for(children_count: 2)).to eq('4')
    end

    it 'is empty when no benefit applies' do
      expect(pilg_for(disability_group: 0, chaes: false, children_count: 1)).to eq('')
    end

    it 'is empty when the income exceeds the threshold and the benefit was not applied' do
      # 5000 ₴ > граничний дохід 4660 ₴: податок ставка без пільги → колонка порожня.
      expect(pilg_for(disability_group: 2, gross: 500_000)).to eq('')
    end

    it 'reports the benefit actually applied when disability and children both apply' do
      # ПСП на 2 дітей (×2) більша за пільгу по інвалідності (×1.5) → застосована '4'.
      expect(pilg_for(disability_group: 1, children_count: 3)).to eq('4')
    end
  end
end
