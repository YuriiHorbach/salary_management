# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health check', type: :request do
  describe 'GET /up' do
    it 'returns OK when the database is reachable' do
      get '/up'

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('OK')
    end

    it 'returns 503 when the database is unavailable' do
      allow(ActiveRecord::Base).to receive(:connection)
        .and_raise(ActiveRecord::ConnectionNotEstablished)

      get '/up'

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to eq('FAIL')
    end

    it 'does not require authentication' do
      get '/up'

      expect(response).not_to have_http_status(:redirect)
    end
  end
end
