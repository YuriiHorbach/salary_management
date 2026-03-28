require 'rails_helper'

RSpec.describe Vacation, type: :model do
  let(:employee) { create(:employee) }
  let(:vacation) { create(:vacation, employee: employee, period: '2023-01-01') } # Added period

  describe '#pdfo_amount' do
    it 'calculates the correct PDFO amount' do
      vacation.vacation_amount_cents = 10000 # 100.00
      expect(vacation.pdfo_amount).to eq(1800) # 18.00
    end
  end

  describe '#military_amount' do
    it 'calculates the correct military amount' do
      vacation.vacation_amount_cents = 10000 # 100.00
      expect(vacation.military_amount).to eq(500) # 5.00
    end
  end

  describe '#total_amount' do
    it 'calculates the correct total amount' do
      vacation.vacation_amount_cents = 10000 # 100.00
      expect(vacation.total_amount).to eq(10000) # 100.00
    end
  end
end
