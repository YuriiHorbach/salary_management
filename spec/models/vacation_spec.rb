require 'rails_helper'

RSpec.describe Vacation, type: :model do
  let(:employee) { create(:employee) }
  # Ensure vacation is created with a valid period and amount that can be converted to Money
  let(:vacation) { create(:vacation, employee: employee, period: '2023-01-01', vacation_amount_cents: 10000) } # Added period and amount

  describe '#pdfo_amount' do
    it 'calculates the correct PDFO amount' do
      # Assuming pdfo_amount returns a Money object
      expect(vacation.pdfo_amount).to eq(Money.new(1800, 'UAH')) # Compare Money with Money
    end
  end

  describe '#military_amount' do
    it 'calculates the correct military amount' do
      # Assuming military_amount returns a Money object
      expect(vacation.military_amount).to eq(Money.new(500, 'UAH')) # Compare Money with Money
    end
  end

  describe '#total_amount' do
    it 'calculates the correct total amount' do
      # Assuming total_amount should return the vacation_amount_cents as a Money object
      # If total_amount is meant to be calculated differently, this will need adjustment.
      expect(vacation.total_amount).to eq(Money.new(10000, 'UAH'))
    end
  end
end
