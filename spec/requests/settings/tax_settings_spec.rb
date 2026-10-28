# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TaxSettings settings', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /settings/tax_settings/edit' do
    it 'returns successful response' do
      get edit_settings_tax_settings_path
      expect(response).to have_http_status(:ok)
    end

    it 'creates the default settings when none exist and displays their values' do
      expect { get edit_settings_tax_settings_path }.to change(TaxSetting, :count).by(1)

      expect(response.body).to include('0.18')
      expect(response.body).to include('0.05')
      expect(response.body).to include('4660')
      expect(response.body).to include('1664')
    end

    it 'displays the existing settings' do
      create(:tax_setting, income_rate: 0.20, military_rate: 0.03, gran_dohid_uah: 5000, psp_uah: 1600)

      get edit_settings_tax_settings_path

      expect(response.body).to include('0.2')
      expect(response.body).to include('0.03')
      expect(response.body).to include('5000')
      expect(response.body).to include('1600')
    end
  end

  describe 'PATCH /settings/tax_settings' do
    context 'with valid params' do
      it 'persists the new rates and thresholds to the database' do
        patch settings_tax_settings_path, params: {
          tax_setting: {
            income_rate: 0.20,
            military_rate: 0.03,
            gran_dohid_uah: 5000,
            psp_uah: 1600
          }
        }

        expect(response).to redirect_to(edit_settings_tax_settings_path)

        setting = TaxSetting.current
        expect(setting.income_rate).to eq(BigDecimal('0.2'))
        expect(setting.military_rate).to eq(BigDecimal('0.03'))
        expect(setting.gran_dohid_uah).to eq(BigDecimal(5000))
        expect(setting.psp_uah).to eq(BigDecimal(1600))
      end

      it 'keeps a single settings record' do
        create(:tax_setting)

        expect do
          patch settings_tax_settings_path, params: { tax_setting: { income_rate: 0.22 } }
        end.not_to change(TaxSetting, :count)
      end

      it 'shows a success notice after updating' do
        patch settings_tax_settings_path, params: { tax_setting: { income_rate: 0.22 } }

        follow_redirect!
        expect(response.body).to include(I18n.t('flash.settings.tax_settings.updated'))
      end
    end

    context 'with invalid params' do
      it 'does not update the settings and re-renders the edit form' do
        setting = create(:tax_setting, income_rate: 0.18)

        patch settings_tax_settings_path, params: { tax_setting: { income_rate: -1 } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(setting.reload.income_rate).to eq(BigDecimal('0.18'))
        expect(response.body).to include(I18n.t('settings.tax_settings.edit.errors'))
      end
    end
  end

  describe 'settings dashboard' do
    it 'links to the tax settings page' do
      get settings_root_path

      expect(response.body).to include(edit_settings_tax_settings_path)
    end
  end
end
