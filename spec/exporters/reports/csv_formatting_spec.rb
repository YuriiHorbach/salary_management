# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Reports::CsvFormatting do
  let(:formatter) do
    Class.new do
      include Reports::CsvFormatting
    end.new
  end

  describe '#csv_money' do
    it 'formats a value with two decimals and a comma as the decimal separator' do
      expect(formatter.csv_money(10_010.0)).to eq('10010,00')
    end

    it 'rounds floating point noise down to two decimals' do
      expect(formatter.csv_money(4667.5600000000004)).to eq('4667,56')
    end

    it 'renders nil as a zero value' do
      expect(formatter.csv_money(nil)).to eq('0,00')
    end
  end

  describe '#csv_text' do
    it 'renders nil as an empty string' do
      expect(formatter.csv_text(nil)).to eq('')
    end

    it 'leaves ordinary text and the em dash unchanged' do
      expect(formatter.csv_text('Іван Петренко')).to eq('Іван Петренко')
      expect(formatter.csv_text('—')).to eq('—')
    end

    it 'neutralises values that could be interpreted as spreadsheets formulas' do
      expect(formatter.csv_text('=SUM(A1)')).to eq("'=SUM(A1)")
      expect(formatter.csv_text('+1')).to eq("'+1")
      expect(formatter.csv_text('-1')).to eq("'-1")
      expect(formatter.csv_text('@value')).to eq("'@value")
      expect(formatter.csv_text("\tvalue")).to eq("'\tvalue")
      expect(formatter.csv_text("\rvalue")).to eq("'\rvalue")
    end
  end

  describe '#build_csv' do
    it 'prefixes the generated document with the BOM' do
      output = formatter.build_csv { |csv| csv << %w[a b] }

      expect(output).to start_with(Reports::CsvFormatting::BOM)
    end

    it 'uses a semicolon as the delimiter without forcing quotes' do
      output = formatter.build_csv { |csv| csv << %w[a b] }

      expect(output).to eq("#{Reports::CsvFormatting::BOM}a;b\n")
    end

    it 'escapes delimiters and quotes so CSV.parse returns the original values' do
      value = 'a;b"c'

      output = formatter.build_csv { |csv| csv << [value, 'plain'] }
      parsed = CSV.parse(output.delete_prefix(Reports::CsvFormatting::BOM), col_sep: ';')

      expect(parsed).to eq([[value, 'plain']])
    end
  end
end
