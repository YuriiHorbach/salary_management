# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::Period do
  describe '.parse' do
    it 'parses a YYYY-MM string into the first day of the month' do
      period = described_class.parse('2025-05')

      expect(period.date).to eq(Date.new(2025, 5, 1))
      expect(period.to_s).to eq('2025-05')
    end

    it 'returns nil for blank values' do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse('')).to be_nil
    end

    it 'returns nil for invalid values' do
      expect(described_class.parse('2025-13')).to be_nil
      expect(described_class.parse('not-a-month')).to be_nil
    end

    it 'returns the same period when given a period' do
      period = described_class.parse('2025-05')

      expect(described_class.parse(period)).to be(period)
    end

    it 'exposes the year, month and month range' do
      period = described_class.parse('2025-02')

      expect(period.year).to eq(2025)
      expect(period.month).to eq(2)
      expect(period.range).to eq(Date.new(2025, 2, 1)..Date.new(2025, 2, 28))
    end
  end

  describe '.from_date' do
    it 'builds a period from any date inside the month' do
      period = described_class.from_date(Date.new(2025, 5, 17))

      expect(period.to_s).to eq('2025-05')
      expect(period.date).to eq(Date.new(2025, 5, 1))
    end

    it 'returns nil for a blank date' do
      expect(described_class.from_date(nil)).to be_nil
    end
  end
end
