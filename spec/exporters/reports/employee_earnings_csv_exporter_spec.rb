# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Reports::EmployeeEarningsCsvExporter do
  let(:bom) { Reports::CsvFormatting::BOM }

  let(:result) do
    {
      period: Date.new(2025, 5, 1),
      columns: [
        { key: %w[Автопарк водій], department_name: 'Автопарк', position_name: 'водій',
          label: 'Автопарк водій' },
        { key: %w[Ферма доярка], department_name: 'Ферма', position_name: 'доярка',
          label: 'Ферма доярка' },
        { key: %w[Ферма механік], department_name: 'Ферма', position_name: 'механік',
          label: 'Ферма механік' }
      ],
      rows: [
        {
          employee_id: 1,
          id_code: '1234567890',
          full_name: 'Петренко Іван Іванович',
          total_salary: 1750.0,
          earnings: {
            %w[Автопарк водій] => 250.0,
            %w[Ферма доярка] => 1000.0,
            %w[Ферма механік] => 500.0
          }
        },
        {
          employee_id: 2,
          id_code: '0987654321',
          full_name: 'Іваненко Марія Петрівна',
          total_salary: 0.0,
          earnings: {}
        }
      ],
      totals: { salary: 1750.0 }
    }
  end

  def parse(csv)
    CSV.parse(csv.delete_prefix(bom), col_sep: ';')
  end

  it 'starts the document with the BOM' do
    expect(described_class.new(result).call).to start_with(bom)
  end

  it 'renders the fixed headers followed by the dynamic department-position columns' do
    headers = parse(described_class.new(result).call).first

    expect(headers).to eq(
      [
        I18n.t('reports.earnings.id_code'),
        I18n.t('reports.earnings.full_name'),
        I18n.t('reports.earnings.total_salary'),
        'Автопарк водій',
        'Ферма доярка',
        'Ферма механік'
      ]
    )
  end

  it 'renders one row per employee with the total and per-column amounts' do
    rows = parse(described_class.new(result).call)

    expect(rows[1]).to eq(
      ['1234567890', 'Петренко Іван Іванович', '1750,00', '250,00', '1000,00', '500,00']
    )
    expect(rows[2]).to eq(
      ['0987654321', 'Іваненко Марія Петрівна', '0,00', '0,00', '0,00', '0,00']
    )
  end

  it 'renders a totals row after the employee rows' do
    rows = parse(described_class.new(result).call)

    expect(rows.last).to eq([I18n.t('reports.earnings.total'), '', '1750,00', '', '', ''])
  end

  it 'omits the totals row when there are no rows' do
    empty = result.merge(rows: [], totals: { salary: 0.0 })

    expect(parse(described_class.new(empty).call).size).to eq(1)
  end
end
