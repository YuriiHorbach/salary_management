# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Reports::SalarySummaryCsvExporter do
  let(:query) { Reports::SalarySummaryQuery }
  let(:bom) { Reports::CsvFormatting::BOM }
  let(:money_keys) { query::COLUMN_KEYS }

  def row_of(value)
    money_keys.index_with { value }
  end

  let(:result) do
    {
      brigades: {
        'Бригада X' => {
          books: { 'Б1' => row_of(10.0), 'Б2' => row_of(20.0) },
          total: row_of(30.0)
        }
      },
      grand_total: row_of(100.0)
    }
  end

  def parse(csv)
    CSV.parse(csv.delete_prefix(bom), col_sep: ';')
  end

  it 'starts the document with the BOM' do
    expect(described_class.new(result).call).to start_with(bom)
  end

  it 'renders the header as two fixed labels followed by the COLUMN_LABELS values' do
    labels = money_keys.map { |key| query::COLUMN_LABELS[key] }

    expect(parse(described_class.new(result).call).first).to eq(%w[Бригада Книга] + labels)
  end

  it 'renders one row per book with brigade, book code and money cells' do
    rows = parse(described_class.new(result).call)

    expect(rows[1]).to eq(['Бригада X', 'Б1'] + Array.new(money_keys.size, '10,00'))
    expect(rows[2]).to eq(['Бригада X', 'Б2'] + Array.new(money_keys.size, '20,00'))
  end

  it 'renders a brigade total row with the label and an empty book cell' do
    row = parse(described_class.new(result).call)[3]

    expect(row).to eq(['Бригада X — Підсумок', ''] + Array.new(money_keys.size, '30,00'))
  end

  it 'renders the grand total row last' do
    row = parse(described_class.new(result).call).last

    expect(row).to eq(['Всього', ''] + Array.new(money_keys.size, '100,00'))
  end

  it 'renders the header, every book row, every brigade total and the grand total' do
    expect(parse(described_class.new(result).call).size).to eq(1 + 2 + 1 + 1)
  end

  it 'renders only the header and a zero grand total when there are no brigades' do
    empty = { brigades: {}, grand_total: row_of(0.0) }
    rows = parse(described_class.new(empty).call)

    expect(rows.size).to eq(2)
    expect(rows.last).to eq(['Всього', ''] + Array.new(money_keys.size, '0,00'))
  end

  it 'escapes special characters in a brigade name through csv_text' do
    special = {
      brigades: { '=Бригада; "X"' => { books: { 'Б1' => row_of(1.0) }, total: row_of(1.0) } },
      grand_total: row_of(1.0)
    }

    expect(parse(described_class.new(special).call)[1].first).to eq("'=Бригада; \"X\"")
  end
end
