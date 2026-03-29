# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vacation, type: :model do
  let(:employee) { create(:employee) }
  let(:vacation) { build(:vacation, employee: employee, period: '2023-01-01', vacation_amount_cents: 100_000) }

  describe 'callbacks' do
    it 'automatically calculates taxes before validation' do
      vacation.valid?
      expect(vacation.income_tax_cents).to eq(18_000)
      expect(vacation.military_tax_cents).to eq(5_000)
      expect(vacation.net_amount_cents).to eq(77_000)
    end
  end

  describe '#pdfo_amount' do
    it 'calculates the correct PDFO amount' do
      vacation.valid?
      expect(vacation.pdfo_amount).to eq(Money.new(18_000, 'USD'))
    end
  end

  describe '#military_amount' do
    it 'calculates the correct military amount' do
      vacation.valid?
      expect(vacation.military_amount).to eq(Money.new(5_000, 'USD'))
    end
  end
end
