# frozen_string_literal: true

module Settings
  class TaxSettingsController < BaseController
    before_action :set_tax_setting

    def edit; end

    def update
      if @tax_setting.update(tax_setting_params)
        redirect_to edit_settings_tax_settings_path, notice: 'Налаштування податків оновлено.'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_tax_setting
      @tax_setting = TaxSetting.current
    end

    def tax_setting_params
      params.expect(tax_setting: %i[income_rate military_rate gran_dohid_uah psp_uah])
    end
  end
end
