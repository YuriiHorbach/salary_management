# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoneyHelper, type: :helper do
  describe '#format_money' do
    it 'formats cents as a symbol-less currency string with a comma separator' do
      expect(helper.format_money(123_456)).to eq('1234,56')
    end

    it 'produces exactly what number_to_currency rendered for the same amount' do
      expect(helper.format_money(123_456)).to eq(helper.number_to_currency(1234.56))
      expect(helper.format_money(120_040)).to eq(helper.number_to_currency(1200.40))
    end

    it 'treats nil as zero so rows with a missing amount still render' do
      expect(helper.format_money(nil)).to eq(helper.number_to_currency(0.0))
      expect(helper.format_money(nil)).to eq('0,00')
    end

    it 'keeps sub-hryvnia amounts visible with two decimals' do
      expect(helper.format_money(5)).to eq('0,05')
    end
  end

  describe '#money_value' do
    it 'converts cents to a dot-separated number for form inputs' do
      expect(helper.money_value(120_040)).to eq(1200.4)
    end

    it 'treats nil as zero' do
      expect(helper.money_value(nil)).to eq(0.0)
    end
  end
end
