# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaxCalculator, type: :service do
  describe '.call' do
    context 'regular employee without children or disability' do
      # amount 2000.00 UAH -> 200_000 cents
      let(:amount_cents) { 200_000 }

      it 'calculates income and military taxes using PSP' do
        res = described_class.call(amount_cents: amount_cents)

        # psp = 1514 UAH -> 151_400 cents
        # taxable = 200_000 - 151_400 = 48_600
        # income_tax = 48_600 * 0.18 = 8_748
        expect(res[:income_tax_cents]).to eq 8_748

        # military_tax = 200_000 * 0.05 = 10_000
        expect(res[:military_tax_cents]).to eq 10_000

        # net: 200_000 - 8_748 - 10_000 = 181_252
        expect(res[:net_amount_cents]).to eq(amount_cents - 8_748 - 10_000)
      end
    end

    context 'employee with 2 children' do
      let(:amount_cents) { 200_000 }

      it 'applies child PSP rules and often results in zero income tax' do
        res = described_class.call(amount_cents: amount_cents, children_count: 2)

        # child PSP = 1514 * 2 = 3028 UAH -> 302_800 cents; taxable negative => income tax 0
        expect(res[:income_tax_cents]).to eq 0

        # military tax still computed on gross (5%)
        expect(res[:military_tax_cents]).to eq 10_000

        # net: 200_000 - 10_000 = 190_000
        expect(res[:net_amount_cents]).to eq(amount_cents - 10_000)
      end
    end

    context 'employee with disability and small salary' do
      let(:amount_cents) { 100_000 } # 1000.00 UAH

      it 'results in zero income tax, but military tax is calculated' do
        res = described_class.call(amount_cents: amount_cents, disability_group: 1)

        # gross (1000 UAH) < invalidity PSP (1514 UAH) => income tax 0
        expect(res[:income_tax_cents]).to eq 0

        # military tax: 100_000 * 0.05 = 5_000 cents
        expect(res[:military_tax_cents]).to eq 5_000

        # net amount: 100_000 - 0 (ПДФО) - 5_000 (ВЗ) = 95_000
        expect(res[:net_amount_cents]).to eq(amount_cents - 5_000)
      end
    end

    context 'employee has contract' do
      let(:amount_cents) { 100_000 } # 1000.00 UAH

      it 'calculates 18% from salary' do
        res = described_class.call(amount_cents: amount_cents, contract: true)

        expect(res[:income_tax_cents]).to eq 18000
      end

      it 'calculates 18% from salary even if exists disability group' do
        res = described_class.call(amount_cents: amount_cents, disability_group: 1, contract: true)

        expect(res[:income_tax_cents]).to eq 18000
      end
    end
  end
end
