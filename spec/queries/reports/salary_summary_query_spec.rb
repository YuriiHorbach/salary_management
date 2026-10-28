# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::SalarySummaryQuery do
  describe '#call' do
    let!(:department) { create(:department, name: 'Відділ A') }

    let!(:brigade1) { create(:territory_sign, name: 'Бригада 1') }
    let!(:brigade2) { create(:territory_sign, name: 'Бригада 2') }

    let!(:emp1) do
      create(:employee,
        id_code: '1234567890',
        first_name: 'Іван',
        last_name: 'Петренко',
        territory_sign: brigade1)
    end

    let!(:emp2) do
      create(:employee,
        id_code: '2233445566',
        first_name: 'Марія',
        last_name: 'Іваненко',
        territory_sign: brigade1)
    end

    let!(:emp3) do
      create(:employee,
        id_code: '1122334455',
        first_name: 'Петро',
        last_name: 'Сидоренко',
        territory_sign: brigade2)
    end

    let!(:book1) { create(:account_book, code: 'Б11') }
    let!(:book2) { create(:account_book, code: 'Б12') }

    let!(:salary1) do
      create(:salary, employee: emp1, department: department,
        amount_cents: 100_000, income_tax_cents: 18_000, military_tax_cents: 5_000, net_amount_cents: 77_000,
        paid_on: Date.current)
    end

    let!(:salary2) do
      create(:salary, employee: emp2, department: department,
        amount_cents: 150_000, income_tax_cents: 27_000, military_tax_cents: 7_500, net_amount_cents: 115_500,
        paid_on: Date.current)
    end

    let!(:salary3) do
      create(:salary, employee: emp3, department: department,
        amount_cents: 200_000, income_tax_cents: 36_000, military_tax_cents: 10_000, net_amount_cents: 154_000,
        paid_on: Date.current)
    end

    let!(:vacation1) do
      create(:vacation, employee: emp1,
        vacation_amount_cents: 30_000, income_tax_cents: 5_400, military_tax_cents: 1_500, net_amount_cents: 23_100,
        period: Date.current)
    end

    let!(:vacation2) do
      create(:vacation, employee: emp2,
        vacation_amount_cents: 40_000, income_tax_cents: 7_200, military_tax_cents: 2_000, net_amount_cents: 30_800,
        period: Date.current)
    end

    let!(:sick_day1) do
      create(:sick_day, employee: emp1,
        pfu_amount_cents: 20_000, enterprise_amount_cents: 10_000, period: Date.current)
    end

    let!(:sick_day2) do
      create(:sick_day, employee: emp3,
        pfu_amount_cents: 10_000, enterprise_amount_cents: 5_000, period: Date.current)
    end

    before do
      emp1.update!(account_book: book1)
      emp2.update!(account_book: book1)
      emp3.update!(account_book: book2)
    end

    it 'returns aggregated data grouped by brigade and book' do
      result = described_class.new.call

      expect(result[:brigades]).to have_key('Бригада 1')
      expect(result[:brigades]).to have_key('Бригада 2')

      brigade1_result = result[:brigades]['Бригада 1']
      expect(brigade1_result[:books]).to have_key('Б11')

      book_row = brigade1_result[:books]['Б11']
      # emp1 + emp2 are both in Brigada 1 with book Б11
      expect(book_row[:salary_gross_vacation]).to be_within(0.01).of((100_000 + 30_000 + 150_000 + 40_000) / 100.0)
      expect(book_row[:total_income]).to be_within(0.01).of(
        (100_000 + 30_000 + 150_000 + 40_000 + 30_000) / 100.0
      )
    end

    it 'sorts brigades and books in ascending order' do
      brigade1.update!(name: 'Бригада Я')
      brigade2.update!(name: 'Бригада А')
      book1.update!(code: 'Я11')
      book2.update!(code: 'А10')
      emp2.update!(account_book: book2)

      result = described_class.new.call

      expect(result[:brigades].keys).to eq(['Бригада А', 'Бригада Я'])
      expect(result[:brigades]['Бригада Я'][:books].keys).to eq(%w[А10 Я11])
    end

    it 'includes brigade totals' do
      result = described_class.new.call

      brigade1_result = result[:brigades]['Бригада 1']
      expect(brigade1_result[:total][:salary_gross_vacation]).to be > 0
    end

    it 'includes grand total' do
      result = described_class.new.call

      expect(result[:grand_total][:total_income]).to be > 0
    end

    it 'returns empty structure when no data' do
      Employee.destroy_all
      result = described_class.new.call

      expect(result[:brigades]).to be_empty
      expect(result[:grand_total].values.all? { |v| v == 0.0 }).to be true
    end

    it 'has correct column keys and labels' do
      expect(described_class::COLUMN_KEYS).to include(
        :salary_amount,
        :salary_gross_vacation,
        :salary_vacation_income_tax,
        :total_salary,
        :total_income,
        :total_tax,
        :total_military
      )
      expect(described_class::COLUMN_LABELS[:total_income]).to eq('Загальний дохід (зп+вп+лік)')
      expect(described_class::COLUMN_LABELS[:total_tax]).to eq('Загальний податок (зп+вп+лік)')
      expect(described_class::COLUMN_LABELS[:total_military]).to eq('Загальний ВЗ (зп+вп+лік)')
    end

    it 'scopes every aggregate to the requested period' do
      result = described_class.new(period: 1.month.ago.strftime('%Y-%m')).call

      expect(result[:period]).to eq(1.month.ago.beginning_of_month)
      expect(result[:grand_total][:total_income]).to eq(0.0)
    end

    it 'uses the aggregated period incomes instead of per-record taxes' do
      result = described_class.new.call
      book_row = result[:brigades]['Бригада 1'][:books]['Б11']

      expected_tax = EmployeePeriodIncome
                     .for_period(Date.current.beginning_of_month)
                     .where(employee_id: [emp1.id, emp2.id])
                     .sum(:income_tax_cents) / 100.0

      expect(book_row[:total_tax]).to be_within(0.01).of(expected_tax)
    end
  end
end
