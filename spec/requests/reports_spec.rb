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
  end
end
