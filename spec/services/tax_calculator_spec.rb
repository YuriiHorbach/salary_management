# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaxCalculator, type: :service do
  describe '.call' do
    context 'regular employee without children or disability' do
      let(:amount_cents) { 200_000 }

      it 'calculates income and military taxes using PSP' do
        res = described_class.call(amount_cents: amount_cents)

        expect(res[:income_tax_cents]).to eq 6_048
        expect(res[:military_tax_cents]).to eq 10_000
        expect(res[:net_amount_cents]).to eq(amount_cents - 6_048 - 10_000)
      end
    end

    context 'employee with 2 children' do
      let(:amount_cents) { 200_000 }

      it 'applies child PSP rules' do
        res = described_class.call(amount_cents: amount_cents, children_count: 2)

        expect(res[:income_tax_cents]).to eq 0
        expect(res[:military_tax_cents]).to eq 10_000
        expect(res[:net_amount_cents]).to eq(amount_cents - 10_000)
      end
    end

    context 'employee with disability' do
      let(:amount_cents) { 100_000 }

      it 'results in zero income tax for small salary' do
        res = described_class.call(amount_cents: amount_cents, disability_group: 1)

        expect(res[:income_tax_cents]).to eq 0
        expect(res[:military_tax_cents]).to eq 5_000
        expect(res[:net_amount_cents]).to eq(amount_cents - 5_000)
      end
    end

    context 'employee with Chornobyl status' do
      it 'applies the 1.5x PSP' do
        res = described_class.call(amount_cents: 300_000, chaes: true)

        expect(res[:income_tax_cents]).to eq 9_072
        expect(res[:military_tax_cents]).to eq 15_000
      end
    end

    context 'employee with UBD status' do
      it 'applies the 2x PSP' do
        res = described_class.call(amount_cents: 400_000, ubd: true)

        expect(res[:income_tax_cents]).to eq 12_096
        expect(res[:military_tax_cents]).to eq 20_000
      end
    end

    context 'single parent' do
      it 'applies the 1.5x PSP for each child' do
        res = described_class.call(amount_cents: 500_000, single_parent: true, children_count: 2)

        expect(res[:income_tax_cents]).to eq 144
      end

      it 'does not apply the single-parent benefit without children' do
        res = described_class.call(amount_cents: 300_000, single_parent: true)

        expect(res[:income_tax_cents]).to eq 24_048
      end
    end

    context 'employee with a disabled child' do
      it 'applies the 1.5x PSP for the disabled child' do
        res = described_class.call(amount_cents: 400_000, children_disabled_count: 1)

        expect(res[:income_tax_cents]).to eq 27_072
      end
    end

    context 'with multiple eligible benefits' do
      it 'uses the largest PSP and its matching threshold instead of stacking' do
        res = described_class.call(amount_cents: 600_000, ubd: true, children_count: 2)

        # Both UBD and two children give a 3328 UAH PSP; the child threshold
        # (9320 UAH) wins over the base UBD threshold (4660 UAH).
        expect(res[:income_tax_cents]).to eq 48_096
      end
    end

    context 'employee has contract' do
      it 'calculates 18% from 1000 UAH' do
        res = described_class.call(amount_cents: 100_000, contract: true)
        expect(res[:income_tax_cents]).to eq 18_000
      end

      it 'calculates full tax for contract regardless of children (8000 UAH case)' do
        res = described_class.call(amount_cents: 800_000, children_count: 3, contract: true)
        expect(res[:income_tax_cents]).to eq 144_000
      end

      it 'calculates full tax for contract regardless of disability' do
        res = described_class.call(amount_cents: 500_000, disability_group: 2, contract: true)
        expect(res[:income_tax_cents]).to eq 90_000
      end

      it 'applies PSP when contract is explicitly false' do
        res = described_class.call(amount_cents: 700_000, children_count: 3, contract: false)
        expect(res[:income_tax_cents]).to eq 36_144
      end
    end

    context 'when a custom TaxSetting exists' do
      before do
        create(:tax_setting, income_rate: 0.10, military_rate: 0.02, gran_dohid_uah: 10_000, psp_uah: 0)
      end

      it 'picks up the persisted rates and thresholds instead of the constants' do
        res = described_class.call(amount_cents: 200_000)

        expect(res[:income_tax_cents]).to eq 20_000
        expect(res[:military_tax_cents]).to eq 4_000
        expect(res[:net_amount_cents]).to eq(200_000 - 20_000 - 4_000)
      end

      it 'uses the persisted threshold when deciding whether PSP applies' do
        # gran_dohid_uah: 10_000 UAH (1_000_000 cents) -> 200_000 cents is below, PSP (0) applied
        below = described_class.call(amount_cents: 900_000)
        expect(below[:income_tax_cents]).to eq 90_000

        # gross above the configured threshold -> no PSP reduction
        above = described_class.call(amount_cents: 2_000_000)
        expect(above[:income_tax_cents]).to eq 200_000
      end

      it 'still lets explicitly passed arguments override the persisted values' do
        res = described_class.call(
          amount_cents: 100_000,
          income_rate: 0.18,
          military_rate: 0.05
        )

        expect(res[:income_tax_cents]).to eq 18_000
        expect(res[:military_tax_cents]).to eq 5_000
      end
    end

    context 'when no TaxSetting exists yet' do
      it 'creates the default settings from the TaxSetting defaults' do
        expect { described_class.call(amount_cents: 200_000) }
          .to change(TaxSetting, :count).by(1)

        setting = TaxSetting.current
        expect(setting.income_rate).to eq(TaxSetting::DEFAULTS[:income_rate])
        expect(setting.military_rate).to eq(TaxSetting::DEFAULTS[:military_rate])
        expect(setting.gran_dohid_uah).to eq(TaxSetting::DEFAULTS[:gran_dohid_uah])
        expect(setting.psp_uah).to eq(TaxSetting::DEFAULTS[:psp_uah])
      end
    end
  end
end
