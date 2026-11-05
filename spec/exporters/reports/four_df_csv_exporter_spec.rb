# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Reports::FourDfCsvExporter do
  let(:bom) { Reports::CsvFormatting::BOM }

  let(:row) do
    Reports::FourDfQuery::Row.new(
      tin: '1234567890',
      gross_cents: 2_049_800,
      income_tax_cents: 368_964,
      military_tax_cents: 102_490,
      pilg: '2'
    )
  end

  def parse(csv)
    CSV.parse(csv.delete_prefix(bom), col_sep: ';')
  end

  it 'starts the document with the BOM' do
    expect(described_class.new([row]).call).to start_with(bom)
  end

  it 'renders the exact 25 M.E.Doc header cells in the required order' do
    headers = parse(described_class.new([row]).call).first

    expect(headers.size).to eq(25)
    expect(headers).to eq(
      %w[
        TIN,C,10 S_NAR,N,14,2 S_DOX,N,14,2 S_TAXN,N,14,2 S_TAXP,N,14,2
        A051,N,12,2 A05,N,12,2 OZN_DOX,N,3 D_PRIYN,D D_ZVILN,D
        OZN_PILG,C,2 OZNAKA,C,1 R3_TIN,C,10 DOGNUM,C,10 DOGDATE,D
        D_DEADLINE,D GRANT_DEST DATE_EXEC,D GRANT_SUM FACT,N,14,2
        TAB2_A91,N,1 TAB2_A9,N,14 TAB2_A101,N,1 TAB2_A10,N,14 R3_OZN,N,1,0
      ]
    )
  end

  it 'formats monetary cells with a comma decimal separator' do
    cells = parse(described_class.new([row]).call).last

    expect(cells.values_at(1, 2)).to eq(['20498,00', '20498,00']) # S_NAR, S_DOX
    expect(cells.values_at(3, 4)).to eq(['3689,64', '3689,64'])   # S_TAXN, S_TAXP
    expect(cells.values_at(5, 6)).to eq(['1024,90', '1024,90'])   # A051, A05
  end

  it 'zero-pads a numeric TIN to ten digits' do
    short_row = Reports::FourDfQuery::Row.new(
      tin: '12345', gross_cents: 0, income_tax_cents: 0, military_tax_cents: 0
    )
    cells = parse(described_class.new([short_row]).call).last

    expect(cells[0]).to eq('0000012345')
  end

  it 'sets the salary income sign' do
    cells = parse(described_class.new([row]).call).last

    expect(cells[7]).to eq('101') # OZN_DOX: заробітна плата
  end

  it 'renders the OZN_PILG benefit sign computed by the query' do
    cells = parse(described_class.new([row]).call).last

    expect(cells[10]).to eq('2')
  end

  it 'renders an empty OZN_PILG when the query reports no benefit' do
    plain = Reports::FourDfQuery::Row.new(
      tin: '1234567890', gross_cents: 0, income_tax_cents: 0, military_tax_cents: 0
    )
    cells = parse(described_class.new([plain]).call).last

    expect(cells[10]).to eq('')
  end

  it 'leaves fields without a data source empty' do
    cells = parse(described_class.new([row]).call).last

    # D_PRIYN, D_ZVILN, OZNAKA, R3_TIN, DOGNUM, DOGDATE, D_DEADLINE,
    # GRANT_DEST, DATE_EXEC, GRANT_SUM, FACT, TAB2_A91, TAB2_A9,
    # TAB2_A101, TAB2_A10, R3_OZN
    expect(cells.values_at(8, 9, *11..24)).to eq(Array.new(16, ''))
  end

  it 'renders one data row per employee' do
    other = Reports::FourDfQuery::Row.new(
      tin: '0987654321', gross_cents: 0, income_tax_cents: 0, military_tax_cents: 0
    )

    expect(parse(described_class.new([row, other]).call).size).to eq(3)
  end
end
