# frozen_string_literal: true

module Settings
  # Manages application-wide preferences exposed from the settings dashboard.
  #
  # The only preference currently editable here is the default UI locale, which
  # +ApplicationController#set_locale+ uses when no supported +locale+ query
  # parameter is present.
  class ApplicationSettingsController < BaseController
    before_action :set_application_setting

    def edit; end

    def update
      if @application_setting.update(application_setting_params)
        redirect_to edit_settings_application_setting_path,
                    notice: t('flash.settings.application_settings.updated',
                              locale: confirmation_locale)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_application_setting
      @application_setting = ApplicationSetting.current
    end

    def application_setting_params
      params.expect(application_setting: [:default_locale])
    end

    # Uses the language the user is currently viewing when they explicitly
    # selected one; otherwise confirms in the newly configured default.
    #
    # @return [Symbol, String] locale for the confirmation message
    def confirmation_locale
      @locale_from_param ? I18n.locale : @application_setting.default_locale
    end
  end
end
