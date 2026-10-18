# frozen_string_literal: true

require 'rails_helper'
require 'csv'

FULLY_POPULATED_ROW = [
  '1234567890', 'Б99', 'Бригада X', 'Відділ X', 'Іван Петренко',
  '1000.00', '180.00', '50.00', '770.00',
  '300.00', '54.00', '15.00',
  '300.00', '54.00', '15.00',
  '1300.00', '1600.00', '288.00', '80.00', '1232.00'
].freeze

RSpec.shared_context 'with a fully populated employee' do
  let(:department) { create(:department, name: 'Відділ X') }
  let(:brigade) { create(:territory_sign, name: 'Бригада X') }
  let(:employee) do
    create(:employee, id_code: '1234567890', first_name: 'Іван', last_name: 'Петренко',
                      territory_sign: brigade, children_count: 0)
  end
  let(:rows) { Nokogiri::HTML(response.body).css('table tbody tr') }
  let!(:salary) do
    create(:salary, employee: employee, department: department, amount_cents: 100_000,
                    income_tax_cents: 18_000, military_tax_cents: 5_000, net_amount_cents: 77_000)
  end

  before do
    create(:account_book, employee: employee, code: 'Б99')
    create(:department_employee, employee: employee, department: department)
    create(:vacation, employee: employee, vacation_amount_cents: 30_000, income_tax_cents: 5_400,
                      military_tax_cents: 1_500, net_amount_cents: 23_100)
    create(:sick_day, employee: employee, pfu_amount_cents: 20_000,
                      enterprise_amount_cents: 10_000, period: Date.current)
    get detailed_reports_path
  end
end

RSpec.describe 'Reports', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:employee) { create(:employee, children_count: 0) }
  let!(:salary) { create(:salary, employee: employee, amount_cents: 300_000) }

  before do
    sign_in user
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'GET /reports/summary' do
    it 'returns a successful response' do
      get summary_reports_path

      expect(response).to have_http_status(:ok)
    end

    it 'returns aggregated summary data' do
      get summary_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Загальний дохід')
      expect(response.body).to include('Загальний податок')
    end

    it 'splits the first column into separate Brigade and Book headers' do
      get summary_reports_path

      doc = Nokogiri::HTML(response.body)
      headers = doc.css('table thead tr').first.css('th').map { |th| th.text.strip }

      expect(headers.first).to eq('Бригада')
      expect(headers.second).to eq('Книга')
      expect(headers).not_to include('Бригада / Книга')
    end

    it 'renders one header cell per table column' do
      get summary_reports_path

      doc = Nokogiri::HTML(response.body)
      header_cells = doc.css('table thead tr').first.css('th').size
      first_data_cells = doc.css('table tbody tr').first.css('td').size

      expect(header_cells).to eq(Reports::SalarySummaryQuery::COLUMN_KEYS.size + 2)
      expect(first_data_cells).to eq(header_cells)
    end

    context 'when requesting CSV' do
      it 'returns a CSV attachment response' do
        get summary_reports_path(format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include("summary-#{Date.current}.csv")
      end

      it 'renders a parseable CSV document' do
        get summary_reports_path(format: :csv)

        rows = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';')

        expect(rows).to be_an(Array)
        expect(rows.first).to be_present
        expect(rows.first.first(2)).to eq(%w[Бригада Книга])
        expect(rows.last.first).to eq('Всього')
      end

      it 'keeps the html behavior untouched when no format is given' do
        get summary_reports_path

        expect(response.media_type).to eq('text/html')
      end
    end
  end

  describe 'GET /reports/detailed' do
    it 'returns a successful response' do
      get detailed_reports_path

      expect(response).to have_http_status(:ok)
    end

    it 'renders the detailed report table' do
      get detailed_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('ІПН')
      expect(response.body).to include('ПІБ')
      expect(response.body).to include('detailed_report_table')
    end

    it 'filters by brigade' do
      get detailed_reports_path, params: { brigade: employee.territory_info }

      expect(response).to have_http_status(:ok)
    end

    it 'filters by date range' do
      get detailed_reports_path,
          params: { date_from: Date.current.beginning_of_month, date_to: Date.current.end_of_month }

      expect(response).to have_http_status(:ok)
    end

    it 'renders one header cell per data column so every column has a label' do
      get detailed_reports_path

      doc = Nokogiri::HTML(response.body)
      header_cells = doc.css('table thead tr').first.css('th').size
      first_data_cells = doc.css('table tbody tr').first.css('td').size

      expect(header_cells).to eq(first_data_cells)
    end

    it 'labels the gross salary+vacation and the last net pay columns' do
      get detailed_reports_path

      doc = Nokogiri::HTML(response.body)
      headers = doc.css('table thead tr').first.css('th').map { |th| th.text.strip }

      expect(headers).to include('Брутто зп+відп')
      expect(headers.last).to eq('Чиста виплата')
    end

    it 'renders the header cells with the exact labels, order and alignment classes' do
      get detailed_reports_path

      doc = Nokogiri::HTML(response.body)
      header_cells = doc.css('table thead tr').first.css('th')

      Reports::EmployeeDetailedQuery::COLUMN_LABELS.each_with_index do |(key, label), index|
        alignment = Reports::EmployeeDetailedQuery::TEXT_COLUMNS.include?(key) ? 'text-left' : 'text-right'

        expect(header_cells[index].text.strip).to eq(label)
        expect(header_cells[index]['class']).to include(alignment)
      end
    end

    it 'renders a single empty-state cell spanning all columns' do
      get detailed_reports_path, params: { brigade: 999_999 }

      doc = Nokogiri::HTML(response.body)
      cells = doc.css('table tbody tr').first.css('td')

      expect(cells.size).to eq(1)
      expect(cells.first['colspan']).to eq('20')
    end

    context 'with a fully populated employee' do
      include_context 'with a fully populated employee'

      it 'renders the employee cells in the expected column order' do
        expect(rows.first.css('td').map { |td| td.text.strip }).to eq(FULLY_POPULATED_ROW)
      end

      it 'aligns numeric cells right and emphasises full_name and net_pay' do
        cells = rows.first.css('td')

        expect(cells[4]['class']).to include('font-medium')
        expect(cells[4]['class']).not_to include('text-right')
        expect(cells[5..].map { |td| td['class'] }).to all(include('text-right'))
        expect(cells[19]['class']).to include('text-right', 'font-semibold')
      end

      it 'renders the totals row with a spanning label and the numeric totals' do
        cells = rows.last.css('td')

        expect(cells.size).to eq(16)
        expect(cells.first['colspan']).to eq('5')
        expect(cells.first.text.strip).to eq('Загалом')
        expect(cells[1..].map { |td| td.text.strip }).to eq(FULLY_POPULATED_ROW[5..])
      end
    end

    context 'when requesting CSV' do
      let(:brigade_one) { create(:territory_sign, name: 'Бригада Один') }
      let(:brigade_two) { create(:territory_sign, name: 'Бригада Два') }
      let(:employee_one) do
        create(:employee, id_code: '1111111111', first_name: 'Перший', last_name: 'Працівник',
                          territory_sign: brigade_one)
      end
      let(:employee_two) do
        create(:employee, id_code: '2222222222', first_name: 'Другий', last_name: 'Працівник',
                          territory_sign: brigade_two)
      end

      let(:csv_rows) { CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';') }
      let(:csv_id_codes) { csv_rows[1..].map(&:first) }

      before do
        create(:salary, employee: employee_one)
        create(:salary, employee: employee_two)
      end

      it 'returns a CSV attachment response with the detailed filename' do
        get detailed_reports_path(format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include("detailed-#{Date.current}.csv")
      end

      it 'renders a parseable CSV document headed by ІПН' do
        get detailed_reports_path(format: :csv)

        expect(csv_rows).to be_an(Array)
        expect(csv_rows.first.first).to eq('ІПН')
      end

      it 'includes both employees from different brigades' do
        get detailed_reports_path(format: :csv)

        expect(csv_id_codes).to include('1111111111', '2222222222')
      end

      it 'filters the CSV rows by the brigade parameter' do
        get detailed_reports_path(format: :csv), params: { brigade: brigade_one.id }

        expect(csv_id_codes).to include('1111111111')
        expect(csv_id_codes).not_to include('2222222222')
      end

      it 'keeps the html behavior untouched when no format is given' do
        get detailed_reports_path

        expect(response.media_type).to eq('text/html')
      end
    end
  end

  describe 'CSV export without authentication' do
    before { sign_out user }

    it 'does not return the summary data' do
      get summary_reports_path(format: :csv)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Content-Disposition']).to be_nil
    end

    it 'does not return the detailed data' do
      get detailed_reports_path(format: :csv)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Content-Disposition']).to be_nil
    end
  end
end
