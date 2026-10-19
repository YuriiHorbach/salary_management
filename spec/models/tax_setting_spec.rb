# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaxSetting, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:tax_setting)).to be_valid
    end

    it 'is invalid without income_rate' do
      expect(build(:tax_setting, income_rate: nil)).to be_invalid
    end

    it 'is invalid without military_rate' do
      expect(build(:tax_setting, military_rate: nil)).to be_invalid
    end

    it 'is invalid without gran_dohid_uah' do
      expect(build(:tax_setting, gran_dohid_uah: nil)).to be_invalid
    end

    it 'is invalid without psp_uah' do
      expect(build(:tax_setting, psp_uah: nil)).to be_invalid
    end

    it 'is invalid with negative values' do
      expect(build(:tax_setting, income_rate: -0.1)).to be_invalid
    end
  end

  describe '.current' do
    context 'when no settings exist yet' do
      it 'creates a single default record from the TaxSetting defaults' do
        expect { described_class.current }.to change(described_class, :count).by(1)

        setting = described_class.current

        expect(setting.income_rate).to eq(described_class::DEFAULTS[:income_rate])
        expect(setting.military_rate).to eq(described_class::DEFAULTS[:military_rate])
        expect(setting.gran_dohid_uah).to eq(described_class::DEFAULTS[:gran_dohid_uah])
        expect(setting.psp_uah).to eq(described_class::DEFAULTS[:psp_uah])
      end
    end

    context 'when a setting already exists' do
      it 'returns the existing record instead of creating a new one' do
        existing = create(:tax_setting, income_rate: 0.20)

        expect { described_class.current }.not_to change(described_class, :count)
        expect(described_class.current).to eq(existing)
      end
    end

    it 'does not create duplicates when called repeatedly' do
      described_class.current

      expect { described_class.current }.not_to change(described_class, :count)
    end
  end
end
