# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SickDay, type: :model do
  let(:sick_day) { build(:sick_day) }

  describe 'validations' do
    it 'is not valid when period is missing' do
      invalid_sick_day = build(:sick_day, period: nil)

      expect(invalid_sick_day).not_to be_valid
      expect(invalid_sick_day.errors.added?(:period, :blank)).to be(true)
    end

    it 'is invalid with negativ value of pfu_amount' do
      invalid_sick_day = build(:sick_day, pfu_amount: -100_000)

      expect(invalid_sick_day).not_to be_valid
      expect(invalid_sick_day.errors[:pfu_amount]).to include('must be greater than or equal to 0')
    end

    it 'is invalid with negativ value of enterprise_amount' do
      invalid_sick_day = build(:sick_day, enterprise_amount: -50_000)

      expect(invalid_sick_day).not_to be_valid
      expect(invalid_sick_day.errors[:enterprise_amount]).to include('must be greater than or equal to 0')
    end

    it 'is valid with correct period format (YYYY-MM)' do
      valid_date = Date.parse('2026-01-01')
      valid_sick_day = build(:sick_day, period: valid_date)

      expect(valid_sick_day).to be_valid
    end

    it 'treats blank amount inputs as zero' do
      sick_day = build(:sick_day, pfu_amount: '', enterprise_amount: '', period: Date.new(2026, 1, 1))

      expect(sick_day).to be_valid
      expect(sick_day.pfu_amount_cents).to eq(0)
      expect(sick_day.enterprise_amount_cents).to eq(0)
    end

    it 'reports an error instead of raising when pfu_amount exceeds the integer range' do
      sick_day = build(:sick_day, pfu_amount: '111111111111.00')

      expect { sick_day.valid? }.not_to raise_error
      expect(sick_day).not_to be_valid
      expect(sick_day.errors[:pfu_amount]).to include(
        I18n.t('activerecord.errors.models.sick_day.attributes.pfu_amount.amount_too_large')
      )
    end

    it 'reports an error instead of raising when enterprise_amount exceeds the integer range' do
      sick_day = build(:sick_day, enterprise_amount: '111111111111.00')

      expect { sick_day.valid? }.not_to raise_error
      expect(sick_day).not_to be_valid
      expect(sick_day.errors[:enterprise_amount]).to include(
        I18n.t('activerecord.errors.models.sick_day.attributes.enterprise_amount.amount_too_large')
      )
    end
  end

  describe '.current_month_summary' do
    it 'returns each employee with their current month sick day count and the grand total' do
      first_employee = create(:employee, last_name: 'Коваленко')
      second_employee = create(:employee, last_name: 'Бондаренко')

      create_list(:sick_day, 2, employee: first_employee, period: Date.current.beginning_of_month)
      create(:sick_day, employee: second_employee, period: Date.current.beginning_of_month)

      rows, total = described_class.current_month_summary

      expect(rows.map { |row| [row.employee, row.sick_days_count] }).to contain_exactly(
        [first_employee, 2],
        [second_employee, 1]
      )
      expect(total).to eq(3)
    end

    it 'excludes sick days from other months' do
      current_employee = create(:employee, last_name: 'Коваленко')
      previous_month_employee = create(:employee, last_name: 'Бондаренко')

      create(:sick_day, employee: current_employee, period: Date.current.beginning_of_month)
      create(:sick_day, employee: previous_month_employee, period: Date.current.beginning_of_month - 1.month)

      rows, total = described_class.current_month_summary

      expect(rows.map(&:employee)).to contain_exactly(current_employee)
      expect(total).to eq(1)
    end

    it 'returns no rows and a zero total when there are no current month sick days' do
      rows, total = described_class.current_month_summary

      expect(rows).to be_empty
      expect(total).to eq(0)
    end

    it 'uses the provided working month instead of the calendar current month' do
      working_month = Date.current.beginning_of_month - 1.month
      employee = create(:employee, last_name: 'Коваленко')
      create(:sick_day, employee: employee, period: working_month)

      rows, total = described_class.current_month_summary(working_month)

      expect(rows.map(&:employee)).to contain_exactly(employee)
      expect(total).to eq(1)
    end
  end

  describe '.report_for_month' do
    it 'returns per-employee sick day counts for the requested month' do
      first_employee = create(:employee)
      second_employee = create(:employee)
      create_list(:sick_day, 2, employee: first_employee, period: Date.new(2026, 3, 1))
      create(:sick_day, employee: second_employee, period: Date.new(2026, 3, 1))
      create(:sick_day, employee: first_employee, period: Date.new(2026, 4, 1))

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
      create(:sick_day, employee: first_employee, period: Date.new(2026, 3, 1),
                        pfu_amount: 30, enterprise_amount: 20)
      create(:sick_day, employee: first_employee, period: Date.new(2026, 3, 1),
                        pfu_amount: 70, enterprise_amount: 30)
      create(:sick_day, employee: second_employee, period: Date.new(2026, 3, 1),
                        pfu_amount: 10, enterprise_amount: 5)
    end

    it 'returns per-employee counts and monetary totals for the requested month' do
      rows = described_class.report_rows_for_month('2026-03')

      expect(rows.find { |row| row.employee_id == first_employee.id }).to have_attributes(
        sick_days_count: 2, pfu_cents: 10_000, enterprise_cents: 5_000, total_cents: 15_000
      )
      expect(rows.find { |row| row.employee_id == second_employee.id }).to have_attributes(
        sick_days_count: 1, pfu_cents: 1_000, enterprise_cents: 500, total_cents: 1_500
      )
    end

    it 'returns an empty array for a malformed or blank month' do
      expect(described_class.report_rows_for_month('not-a-month')).to eq([])
      expect(described_class.report_rows_for_month(nil)).to eq([])
    end
  end

  describe 'financial logic' do
    let(:period) { Date.new(2026, 1, 1) }
    let(:sick_day) do
      create(:sick_day, pfu_amount: 1000.50, enterprise_amount: 500.50, period: period)
    end

    it 'calculates total amount correctly' do
      expect(sick_day.total_amount.amount).to eq(1501.00)
    end

    it 'calculates PDFO as 18% of the total amount' do
      expect(sick_day.pdfo_amount.amount).to eq(270.18)
    end

    it 'calculates military tax as 5% of the total amount' do
      expect(sick_day.military_amount.amount).to eq(75.05)
    end

    it 'stores the calculated taxes in the tax columns' do
      expect(sick_day.income_tax_cents).to eq(27_018)
      expect(sick_day.military_tax_cents).to eq(7_505)
      expect(sick_day.net_amount_cents).to eq(115_577)
    end

    it 'handles critical rounding with 5% rate' do
      special_sd = create(:sick_day, pfu_amount: Money.new(10_027), enterprise_amount: 0, period: period)

      expect(special_sd.military_amount.cents).to eq(501)
    end

    it 'defaults amounts to 0' do
      sick_day = SickDay.new # not use build(:sick_day) cause it will create non empty factory object

      expect(sick_day.pfu_amount).to eq(0)
      expect(sick_day.enterprise_amount).to eq(0)
    end

    it 'returns an integer for pdfo_amount cents' do
      expect(sick_day.pdfo_amount.cents).to be_an(Integer)
    end

    it 'returns a positive pdfo_amount' do
      expect(sick_day.pdfo_amount).to be > 0
    end

    it 'returns a positive enterprise_amount' do
      expect(sick_day.enterprise_amount).to be > 0
    end

    it 'compares pdfo_amount with military_amount' do
      expect(sick_day.pdfo_amount).to be > sick_day.military_amount
    end

    it 'assigns zero taxes for a zero total amount' do
      zero_sd = create(:sick_day, pfu_amount_cents: 0, enterprise_amount_cents: 0, period: period)

      expect(zero_sd.income_tax_cents).to eq(0)
      expect(zero_sd.military_tax_cents).to eq(0)
      expect(zero_sd.net_amount_cents).to eq(0)
    end

    it 'applies a changed TaxSetting only to new records' do
      old_sick_day = create(:sick_day, pfu_amount_cents: 100_000, enterprise_amount_cents: 0, period: period)
      expect(old_sick_day.income_tax_cents).to eq(18_000)

      TaxSetting.current.update!(income_rate: 0.20)

      new_sick_day = create(:sick_day, pfu_amount_cents: 100_000, enterprise_amount_cents: 0,
                                       period: Date.new(2026, 2, 1))

      expect(new_sick_day.income_tax_cents).to eq(20_000)
      expect(old_sick_day.reload.income_tax_cents).to eq(18_000)
      expect(old_sick_day.pdfo_amount.amount).to eq(180.00)
    end

    it 'recalculates taxes when the amount is edited' do
      sick_day.update!(pfu_amount_cents: 200_000, enterprise_amount_cents: 0)

      expect(sick_day.income_tax_cents).to eq(36_000)
      expect(sick_day.military_tax_cents).to eq(10_000)
      expect(sick_day.net_amount_cents).to eq(154_000)
      expect(sick_day.pdfo_amount.amount).to eq(360.00)
      expect(sick_day.military_amount.amount).to eq(100.00)
    end
  end
end
