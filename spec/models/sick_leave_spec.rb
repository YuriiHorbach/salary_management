require 'rails_helper'

RSpec.describe SickLeave, type: :model do

  let(:sick_leave) { build(:sick_leave) }

  describe 'validations' do 
    it 'is not valid when period is missing' do 
      invalid_sick_leave = build(:sick_leave, period: nil)
  
      expect(invalid_sick_leave).not_to be_valid
      expect(invalid_sick_leave.errors.added?(:period, :blank)).to be(true)
    end
  
    it 'is invalid with negativ value of pfu_amount' do 
      invalid_sick_leave = build(:sick_leave, pfu_amount: -100000)
  
      expect(invalid_sick_leave).not_to be_valid
      expect(invalid_sick_leave.errors[:pfu_amount]).to include("must be greater than or equal to 0")
    end
  
    it 'is invalid with negativ value of enterprise_amount' do 
      invalid_sick_leave = build(:sick_leave, enterprise_amount: -50000)
  
      expect(invalid_sick_leave).not_to be_valid
      expect(invalid_sick_leave.errors[:enterprise_amount]).to include("must be greater than or equal to 0")
    end
  
    it 'is valid with correct period format (YYYY-MM)' do
      valid_sick_leave = build(:sick_leave, period: "2026-01")
      expect(valid_sick_leave).to be_valid
    end
  end

  describe 'financial logic' do 
    let(:sick_leave) { build(:sick_leave, pfu_amount: 100000, enterprise_amount: 50000) }

    it 'calculates total amount correctly' do
      expect(sick_leave.total_amount).to eq(150000)
    end

    it 'calculates PDFO correctly' do
      expect(sick_leave.pdfo_amount).to eq(27000) 
    end

    it 'calculates military tax correctly' do
      expect(sick_leave.military_amount).to eq(7500)
    end

    it 'defaults amounts to 0' do
      sick_leave = SickLeave.new #not use build(:sick_leave) cause it will create non empty factory object

      expect(sick_leave.pfu_amount).to eq(0)
      expect(sick_leave.enterprise_amount).to eq(0)
    end

    it 'returns an integer for pdfo_amount' do
      expect(sick_leave.pdfo_amount).to be_an(Integer)
    end

    it 'returns a positive pdfo_amount' do
      expect(sick_leave.pdfo_amount).to be > 0
    end

    it 'returns a positive pdfo_amount' do
      expect(sick_leave.enterprise_amount).to be > 0
    end

    it 'compare pdfo_amount with military_amount' do 
      expect(sick_leave.pdfo_amount).to be > sick_leave.military_amount
    end
  end
end