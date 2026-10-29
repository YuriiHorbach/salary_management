# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::SalaryVacationTaxCalculator, type: :service do
  describe '.call' do
    let(:employee) do
      create(:employee, children_count: 0, disability_group: 0, chaes: false, contract: false)
    end

    it 'calculates the tax social benefit on the combined salary and vacation gross' do
      result = described_class.call(employee: employee, gross_cents: 130_000)
      expected = TaxCalculator.call(amount_cents: 130_000, children_count: 0, disability_group: 0,
                                    chaes: false, contract: false)

      expect(result).to eq(expected)
      expect(result[:income_tax_cents]).to eq(0)
      expect(result[:military_tax_cents]).to eq(6_500)
    end

    it 'applies the employee tax benefits to the combined gross' do
      employee = create(:employee, children_count: 2)

      result = described_class.call(employee: employee, gross_cents: 300_000)
      expected = TaxCalculator.call(amount_cents: 300_000, children_count: 2, disability_group: 0,
                                    chaes: false, contract: false)

      expect(result).to eq(expected)
      expect(result[:income_tax_cents]).to eq(0)
    end

    it 'uses preloaded tax settings when provided' do
      settings = TaxSetting.current

      allow(TaxSetting).to receive(:current)

      result = described_class.call(employee: employee, gross_cents: 100_000, settings: settings)

      expect(result[:income_tax_cents]).to eq(0)
      expect(TaxSetting).not_to have_received(:current)
    end
  end
end
