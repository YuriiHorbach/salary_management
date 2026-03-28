require 'rails_helper'

RSpec.describe Vacation, type: :model do
  let(:employee) { create(:employee) }
  let(:vacation) { create(:vacation, employee: employee) }

  describe 'associations' do
    it { should belong_to(:employee) }
  end

  describe 'validations' do
    it { should validate_presence_of(:period) }
    it { should validate_numericality_of(:vacation_amount).is_greater_than_or_equal_to(0) }
  end

  describe 'attributes' do
    it 'has a period attribute' do
      expect(vacation.period).to be_a(Date)
    end

    it 'has a vacation_amount_cents attribute' do
      expect(vacation.vacation_amount_cents).to be_a(Integer)
    end
  end

  describe 'ransackable_attributes' do
    it 'returns the correct ransackable attributes' do
      expect(Vacation.ransackable_attributes).to include('period', 'vacation_amount_cents', 'income_tax_cents', 'military_tax_cents', 'net_amount_cents', 'created_at')
    end
  end

  describe 'ransackable_associations' do
    it 'returns the correct ransackable associations' do
      expect(Vacation.ransackable_associations).to include('employee')
    end
  end

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
end
