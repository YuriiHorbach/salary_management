# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportsHelper, type: :helper do
  describe '#detailed_report_cell_class' do
    it 'left-aligns text columns and emphasises full_name' do
      expect(helper.detailed_report_cell_class(:id_code)).to eq('border border-gray-300 px-3 py-2 text-sm')
      expect(helper.detailed_report_cell_class(:full_name))
        .to eq('border border-gray-300 px-3 py-2 text-sm font-medium')
    end

    it 'right-aligns numeric columns and bolds net_pay' do
      expect(helper.detailed_report_cell_class(:base_salary))
        .to eq('border border-gray-300 px-3 py-2 text-right text-sm')
      expect(helper.detailed_report_cell_class(:net_pay))
        .to eq('border border-gray-300 px-3 py-2 text-right text-sm font-semibold')
    end

    it 'drops emphasis for the totals row' do
      expect(helper.detailed_report_cell_class(:net_pay, emphasize: false))
        .to eq('border border-gray-300 px-3 py-2 text-right text-sm')
    end
  end

  describe '#detailed_report_cell_value' do
    it 'returns text as-is and formats numbers to two decimals' do
      expect(helper.detailed_report_cell_value(:full_name, { full_name: 'Іван Петренко' })).to eq('Іван Петренко')
      expect(helper.detailed_report_cell_value(:net_pay, { net_pay: 1232.0 })).to eq('1232,00')
    end
  end
end
