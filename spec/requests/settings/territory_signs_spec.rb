# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TerritorySigns settings', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before do
    sign_in user
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'GET /settings/territory_signs' do
    it 'returns successful response' do
      get settings_territory_signs_path
      expect(response).to have_http_status(:ok)
    end

    it 'displays territory signs list' do
      create(:territory_sign, name: 'Бригада А')
      create(:territory_sign, name: 'Бригада Б')

      get settings_territory_signs_path
      expect(response.body).to include('Бригада А')
      expect(response.body).to include('Бригада Б')
    end

    it 'renders the delete link as a Turbo DELETE request' do
      sign = create(:territory_sign, name: 'Бригада В')
      get settings_territory_signs_path

      link = Nokogiri::HTML(response.body).at_css("a[href='#{settings_territory_sign_path(sign)}']")
      expect(link['data-turbo-method']).to eq('delete')
      expect(link['data-turbo-confirm']).to be_present
      expect(link['data-method']).to be_nil
    end
  end

  describe 'GET /settings/territory_signs/new' do
    it 'returns successful response' do
      get new_settings_territory_sign_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /settings/territory_signs' do
    context 'with valid params' do
      it 'creates a new territory sign' do
        expect {
          post settings_territory_signs_path, params: { territory_sign: { name: 'Бригада В' } }
        }.to change(TerritorySign, :count).by(1)

        expect(response).to redirect_to(settings_territory_signs_path)
        follow_redirect!
        expect(response.body).to include('Бригада В')
      end
    end

    context 'with invalid params' do
      it 'does not create and re-renders new template' do
        expect {
          post settings_territory_signs_path, params: { territory_sign: { name: '' } }
        }.not_to change(TerritorySign, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate name' do
      it 'does not create' do
        create(:territory_sign, name: 'Бригада В')

        expect {
          post settings_territory_signs_path, params: { territory_sign: { name: 'Бригада В' } }
        }.not_to change(TerritorySign, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /settings/territory_signs/:id/edit' do
    it 'returns successful response' do
      sign = create(:territory_sign, name: 'Бригада Г')
      get edit_settings_territory_sign_path(sign)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Бригада Г')
    end
  end

  describe 'PATCH /settings/territory_signs/:id' do
    context 'with valid params' do
      it 'updates the territory sign' do
        sign = create(:territory_sign, name: 'Старе імʼя')
        patch settings_territory_sign_path(sign), params: { territory_sign: { name: 'Нове імʼя' } }

        expect(response).to redirect_to(settings_territory_signs_path)
        expect(sign.reload.name).to eq('Нове імʼя')
      end
    end

    context 'with invalid params' do
      it 'does not update' do
        sign = create(:territory_sign, name: 'Оригінал')
        patch settings_territory_sign_path(sign), params: { territory_sign: { name: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(sign.reload.name).to eq('Оригінал')
      end
    end
  end

  describe 'DELETE /settings/territory_signs/:id' do
    it 'deletes the territory sign' do
      sign = create(:territory_sign, name: 'Для видалення')
      expect {
        delete settings_territory_sign_path(sign)
      }.to change(TerritorySign, :count).by(-1)

      expect(response).to redirect_to(settings_territory_signs_path)
    end
  end
end
