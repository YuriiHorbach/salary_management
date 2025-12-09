require 'rails_helper'

RSpec.describe SalaryReportService, type: :service do
  describe '#call' do
    # --- CONTEXT 1: HAPPY PATH AND GROSS FORMULA CHECK ---
    context 'when providing full data for summation' do
      let!(:salary_1) do
        create(:salary, amount: 5000, net_amount_cents: 400_000, income_tax_cents: 90_000, military_tax_cents: 10_000)
      end
      let!(:salary_2) do
        create(:salary, amount: 10_000, net_amount_cents: 800_000, income_tax_cents: 180_000,
                        military_tax_cents: 20_000)
      end

      # We intentionally take all records here as this is the primary data setup context
      let(:records) { Salary.all }

      subject(:report) { described_class.new(records).call }

      # Expected values calculation:
      let(:expected_gross) { 1_500_000 } # (5000 + 10000) * 100
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
        expect(report[:pdfo]).to eq(expected_pdfo)
      end

      it 'correctly calculates military tax' do
        expect(report[:military_tax]).to eq(expected_military_tax)
      end
    end

    # --- CONTEXT 2: ZERO VALUES IN RECORDS ---
    context 'when tax fields in records are zero' do
      # Setup: Create a record with non-zero Gross but zero tax/net amounts
      let!(:salary_zero) do
        create(:salary,
               amount: 3000,
               net_amount_cents: 300_000,
               income_tax_cents: 0,
               military_tax_cents: 0)
      end

      # Isolate the zero-tax record for testing
      let(:records) { Salary.where(amount: 3000) }

      subject(:report) { described_class.new(records).call }

      # Expected values
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
        expect(report[:pdfo]).to eq(expected_zero)
      end

      it 'returns zero for military tax' do
        expect(report[:military_tax]).to eq(expected_zero)
      end
    end

    # --- CONTEXT 3: EMPTY COLLECTION ---
    context 'when the record collection is empty' do
      let(:records) { Salary.none } # Empty ActiveRecord::Relation
      subject(:report) { described_class.new(records).call }
      let(:expected_zero) { 0 }

      it 'returns zero for all totals' do
        expect(report[:gross]).to eq(expected_zero)
        expect(report[:net]).to eq(expected_zero)
        expect(report[:pdfo]).to eq(expected_zero)
        expect(report[:military_tax]).to eq(expected_zero)
      end
    end
  end
end
