# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SalaryReportService, type: :service do
  describe '#call' do
    context 'when providing full data for summation' do
      let!(:salary1) do
        create(:salary, amount_cents: 500_000, net_amount_cents: 400_000, income_tax_cents: 90_000,
                        military_tax_cents: 10_000)
      end
      let!(:salary2) do
        create(:salary, amount_cents: 1_000_000, net_amount_cents: 800_000, income_tax_cents: 180_000,
                        military_tax_cents: 20_000)
      end

      let(:records) { Salary.all }

      subject(:report) { described_class.new(records).call }

      let(:expected_gross) { 1_500_000 }
      let(:expected_net) { 1_200_000 }
      let(:expected_pdfo) { 270_000 }
      let(:expected_military_tax) { 30_000 }

      it 'correctly calculates Gross Total (checking amount * 100 formula)' do
        expect(report[:gross]).to eq(expected_gross)
      end

      it 'correctly calculates Net Total' do
        expect(report[:net]).to eq(expected_net)
      end

      it 'correctly calculates income tax (PDFA)' do
        expect(report[:income_tax]).to eq(expected_pdfo)
      end

      it 'correctly calculates military tax' do
        expect(report[:military_tax]).to eq(expected_military_tax)
      end
    end

    context 'when tax fields in records are zero' do
      # Setup: Create a record with non-zero Gross but zero tax/net amounts
      let!(:salary_zero) do
        create(:salary,
               amount_cents: 300_000,
               net_amount_cents: 300_000,
               income_tax_cents: 0,
               military_tax_cents: 0)
      end

      let(:records) { Salary.where(amount_cents: 300_000) }

      subject(:report) { described_class.new(records).call }

      let(:expected_gross) { 300_000 } # 3000 * 100
      let(:expected_net) { 300_000 }
      let(:expected_zero) { 0 }

      it 'correctly calculates Gross Total' do
        expect(report[:gross]).to eq(expected_gross)
      end

      it 'correctly calculates Net Total' do
        expect(report[:net]).to eq(expected_net)
      end

      it 'returns zero for income tax (PDFA)' do
        expect(report[:income_tax]).to eq(expected_zero)
      end

      it 'returns zero for military tax' do
        expect(report[:military_tax]).to eq(expected_zero)
      end
    end

    context 'when the record collection is empty' do
      let(:records) { Salary.none } # Empty ActiveRecord::Relation
      subject(:report) { described_class.new(records).call }
      let(:expected_zero) { 0 }

      it 'returns zero for all totals' do
        expect(report[:gross]).to eq(expected_zero)
        expect(report[:net]).to eq(expected_zero)
        expect(report[:income_tax]).to eq(expected_zero)
        expect(report[:military_tax]).to eq(expected_zero)
      end
    end

    context 'when two employees have the same salary amount in the same month' do
      let(:period) { Date.current.beginning_of_month }
      let(:records) { Salary.where(period: period).distinct }

      subject(:report) { described_class.new(records).call }

      before do
        create(:salary, employee: create(:employee), amount_cents: 500_000,
                        income_tax_cents: 90_000, military_tax_cents: 25_000,
                        net_amount_cents: 385_000, period: period, paid_on: period)
        create(:salary, employee: create(:employee), amount_cents: 500_000,
                        income_tax_cents: 90_000, military_tax_cents: 25_000,
                        net_amount_cents: 385_000, period: period, paid_on: period)
      end

      it 'counts both salary rows' do
        expect(report[:gross]).to eq(1_000_000)
        expect(report[:income_tax]).to eq(180_000)
        expect(report[:military_tax]).to eq(50_000)
        expect(report[:net]).to eq(770_000)
      end

      it 'loads overall and department totals in two queries' do
        service = described_class.new(records)

        queries = sql_query_count do
          service.call
          service.department_totals
        end

        expect(queries).to eq(2)
      end
    end
  end

  def sql_query_count(&block)
    count = 0
    callback = lambda do |_name, _started, _finished, _id, payload|
      count += 1 unless payload[:cached] || payload[:name] == 'SCHEMA'
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)
    count
  end
end
