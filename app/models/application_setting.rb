# frozen_string_literal: true

# Singleton model for application-wide preferences.
#
# Currently stores the default UI locale used when a request does not include a
# supported +locale+ query parameter. Settings are managed from
# +Settings::ApplicationSettingsController+ and consumed by
# +ApplicationController#set_locale+.
#
# The table is intentionally a singleton: every read goes through the same
# lowest-id row so a persisted default can never be shadowed by another row.
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
    singleton_row || create!(DEFAULTS)
  end

  # Returns the persisted default locale without creating a settings row.
  #
  # Reads the same deterministic singleton row as +current+, so a value saved
  # through the settings page is always the value returned after a page reload.
  #
  # @return [String] one of +SalaryManagement::SUPPORTED_LOCALES+
  def self.default_locale
    singleton_row&.default_locale || DEFAULTS[:default_locale]
  end

  # @return [ApplicationSetting, nil] the canonical singleton row, if present
  def self.singleton_row
    order(:id).first
  end
  private_class_method :singleton_row
end
