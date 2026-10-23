# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application settings', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /settings/application_setting/edit' do
    it 'shows the supported locales and the current default' do
      ApplicationSetting.create!(default_locale: 'uk')

      get edit_settings_application_setting_path

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      options = page.css('select[name="application_setting[default_locale]"] option')

      expect(options.map { |option| option['value'] }).to contain_exactly('en', 'uk', 'de')
      expect(page.at_css('option[selected]')['value']).to eq('uk')
    end
  end

  describe 'PATCH /settings/application_setting' do
    it 'persists the selected default locale and redirects with a notice' do
      ApplicationSetting.create!(default_locale: 'en')

      patch settings_application_setting_path,
            params: { application_setting: { default_locale: 'de' } }

      expect(response).to redirect_to(edit_settings_application_setting_path)
      follow_redirect!

      expect(response.body).to include(I18n.t('flash.settings.application_settings.updated'))
      expect(ApplicationSetting.current.default_locale).to eq('de')
    end

    it 'rejects an unsupported locale' do
      setting = ApplicationSetting.create!(default_locale: 'en')

      patch settings_application_setting_path,
            params: { application_setting: { default_locale: 'fr' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(setting.reload.default_locale).to eq('en')
      expect(response.body).to include(I18n.t('settings.application_settings.edit.errors'))
    end
  end

  describe 'settings dashboard' do
    it 'links to the default language page' do
      get settings_root_path

      expect(response.body).to include(edit_settings_application_setting_path)
    end
  end
end
