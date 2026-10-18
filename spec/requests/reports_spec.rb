# frozen_string_literal: true

require 'rails_helper'

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
  end
end
