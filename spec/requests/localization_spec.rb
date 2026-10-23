# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Localization', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'default locale' do
    it 'renders the application in English by default' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(I18n.locale).to eq(:en)
      expect(response.body).to include('Home')
      expect(response.body).to include('Departments')
      expect(response.body).to include('Employees')
    end
  end

  describe 'locale switching' do
    it 'renders Ukrainian content when locale=uk' do
      get root_path(locale: :uk)

      expect(I18n.locale).to eq(:uk)
      expect(response.body).to include('Головна сторінка')
      expect(response.body).to include('Працівники')
    end

    it 'renders German content when locale=de' do
      get root_path(locale: :de)

      expect(I18n.locale).to eq(:de)
      expect(response.body).to include('Startseite')
      expect(response.body).to include('Mitarbeiter')
    end

    it 'falls back to English for unsupported locales' do
      get root_path(locale: :fr)

      expect(I18n.locale).to eq(:en)
      expect(response.body).to include('Home')
    end

    it 'renders only the three supported language links even if I18n.locales are polluted' do
      allow(I18n).to receive(:available_locales).and_return(%i[en uk de en-BORK])

      get root_path

      expect(response.body).to include('>EN<', '>UA<', '>DE<')
      expect(response.body).not_to include('En Bork')
    end
  end

  describe 'locale preservation' do
    it 'adds the active locale to generated URLs' do
      get employees_path(locale: :uk)

      expect(response.body).to include('/employees/new?locale=uk')
    end

    it 'keeps the current path when switching locale' do
      get employees_path(locale: :uk)

      expect(response.body).to include('/employees?locale=en')
      expect(response.body).to include('/employees?locale=de')
    end
  end
end
