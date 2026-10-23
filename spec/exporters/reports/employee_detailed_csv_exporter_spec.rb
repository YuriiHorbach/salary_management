# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Reports::EmployeeDetailedCsvExporter do
  let(:query) { Reports::EmployeeDetailedQuery }
  let(:bom) { Reports::CsvFormatting::BOM }

  let(:employee) do
    {
      id_code: '1234567890', book_code: 'Б99', brigade: 'Бригада X', department: 'Відділ X',
      full_name: 'Іван "Тест"; П.', base_salary: 1000.0, salary_income_tax: 180.0,
      salary_military_tax: 50.0, salary_net: 770.0, vacation_amount: 300.0, vacation_income_tax: 54.0,
      vacation_military_tax: 15.0, vacation_net: 231.0, sick_total: 300.0, sick_pdfo: 54.0,
      sick_military: 15.0, gross_vacation: 1300.0, total_income: 1600.0, total_tax: 288.0,
      total_military: 80.0, net_pay: 1232.0
    }
  end

  let(:totals) do
    {
      base_salary: 2500.0, salary_income_tax: 450.0, salary_military_tax: 125.0, salary_net: 1925.0,
      vacation_amount: 750.0, vacation_income_tax: 135.0, vacation_military_tax: 37.5, vacation_net: 577.5,
      sick_total: 300.0, sick_pdfo: 54.0, sick_military: 15.0, gross_vacation: 3250.0,
      total_income: 3550.0, total_tax: 639.0, total_military: 177.5, net_pay: 2905.5
    }
  end

  let(:result) { { employees: [employee], totals: totals } }

  def parse(csv)
    CSV.parse(csv.delete_prefix(bom), col_sep: ';')
  end

  describe '#call' do
    it 'starts the document with the BOM' do
      expect(described_class.new(result).call).to start_with(bom)
    end

    it 'renders the header from the translated column labels in key order' do
      labels = query::COLUMN_LABELS.keys.map { |key| I18n.t("reports.detailed_columns.#{key}") }

      expect(parse(described_class.new(result).call).first).to eq(labels)
    end

    it 'renders the header, one row per employee and the totals row' do
      expect(parse(described_class.new(result).call).size).to eq(1 + 1 + 1)
    end

    it 'renders text columns with csv_text and the rest with csv_money' do
      row = parse(described_class.new(result).call)[1]

      expect(row[0]).to eq('1234567890')
      expect(row[4]).to eq('Іван "Тест"; П.')
      expect(row[5]).to eq('1000,00')
      expect(row[19]).to eq('1232,00')
    end

    it 'renders the totals row as a label, empty text cells and money totals' do
      row = parse(described_class.new(result).call).last

      expect(row.first).to eq(I18n.t('reports.detailed.total'))
      expect(row[1..4]).to eq(['', '', '', ''])
      expect(row[5..]).to eq(
        ['2500,00', '450,00', '125,00', '1925,00', '750,00', '135,00', '37,50',
         '300,00', '54,00', '15,00', '3250,00', '3550,00', '639,00', '177,50', '2905,50']
      )
    end

    it 'prefixes formula-like text with an apostrophe' do
      with_formula = { employees: [employee.merge(full_name: '=cmd')], totals: totals }

      expect(parse(described_class.new(with_formula).call)[1][4]).to eq("'=cmd")
    end

    it 'keeps the em dash placeholder unchanged' do
      with_placeholder = { employees: [employee.merge(book_code: '—')], totals: totals }

      expect(parse(described_class.new(with_placeholder).call)[1][1]).to eq('—')
    end

    it 'renders only the header when there are no employees' do
      empty = { employees: [], totals: {} }

      labels = query::COLUMN_LABELS.keys.map { |key| I18n.t("reports.detailed_columns.#{key}") }
      expect(parse(described_class.new(empty).call)).to eq([labels])
    end
  end
end
