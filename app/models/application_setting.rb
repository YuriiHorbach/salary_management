# frozen_string_literal: true

# Singleton model for application-wide preferences.
#
# Currently stores the default UI locale used when a request does not include a
# supported +locale+ query parameter. Settings are managed from
# +Settings::ApplicationSettingsController+ and consumed by
# +ApplicationController#set_locale+.
class ApplicationSetting < ApplicationRecord
  # Values used when the singleton row has not been created yet.
  DEFAULTS = { default_locale: 'en' }.freeze

  validates :default_locale,
            presence: true,
            inclusion: { in: SalaryManagement::SUPPORTED_LOCALES.map(&:to_s) }

  # Returns the singleton settings row, creating it from the defaults the first
  # time it is needed.
  #
  # @return [ApplicationSetting]
  def self.current
    first || create!(DEFAULTS)
  end

  # Returns the persisted default locale without creating a settings row.
  #
  # @return [String] one of +SalaryManagement::SUPPORTED_LOCALES+
  def self.default_locale
    first&.default_locale || DEFAULTS[:default_locale]
  end
end
