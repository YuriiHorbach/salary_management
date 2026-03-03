# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SickDay, type: :model do
  let(:sick_day) { build(:sick_day) }

  describe 'validations' do
    it 'is not valid when period is missing' do
      invalid_sick_day = build(:sick_day, period: nil)

      expect(invalid_sick_day).not_to be_valid
      expect(invalid_sick_day.errors.added?(:period, :blank)).to be(true)
    end

    it 'is invalid with negativ value of pfu_amount' do
      invalid_sick_day = build(:sick_day, pfu_amount: -100_000)

      expect(invalid_sick_day).not_to be_valid
      expect(invalid_sick_day.errors[:pfu_amount]).to include('must be greater than or equal to 0')
    end

    it 'is invalid with negativ value of enterprise_amount' do
      invalid_sick_day = build(:sick_day, enterprise_amount: -50_000)

      expect(invalid_sick_day).not_to be_valid
      expect(invalid_sick_day.errors[:enterprise_amount]).to include('must be greater than or equal to 0')
    end

    it 'is valid with correct period format (YYYY-MM)' do
      valid_date = Date.parse('2026-01-01')
      valid_sick_day = build(:sick_day, period: valid_date)

      expect(valid_sick_day).to be_valid
    end
  end

  describe 'financial logic' do
    let(:sick_day) { build(:sick_day, pfu_amount: 1000.50, enterprise_amount: 500.50) }

    it 'calculates total amount correctly' do
      expect(sick_day.total_amount.amount).to eq(1501.00)
    end

    it 'calculates PDFO correctly' do
      expect(sick_day.pdfo_amount.amount).to eq(270.18)
    end

    it 'calculates military tax correctly' do
      expect(sick_day.military_amount.amount).to eq(75.05)
    end

    it 'handles critical rounding with 5% rate' do
      special_sd = build(:sick_day, pfu_amount: Money.new(10_027), enterprise_amount: 0)

      expect(special_sd.military_amount.cents).to eq(501)
    end

    it 'defaults amounts to 0' do
      sick_day = SickDay.new # not use build(:sick_day) cause it will create non empty factory object

      expect(sick_day.pfu_amount).to eq(0)
      expect(sick_day.enterprise_amount).to eq(0)
    end

    it 'returns an integer for pdfo_amount' do
      expect(sick_day.pdfo_amount.cents).to be_an(Integer)
    end

    it 'returns a positive pdfo_amount' do
      expect(sick_day.pdfo_amount).to be > 0
    end

    it 'returns a positive pdfo_amount' do
      expect(sick_day.enterprise_amount).to be > 0
    end

    it 'compare pdfo_amount with military_amount' do
      expect(sick_day.pdfo_amount).to be > sick_day.military_amount
    end
  end
end
