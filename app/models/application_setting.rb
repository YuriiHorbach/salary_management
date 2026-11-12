# frozen_string_literal: true

# Singleton model for application-wide preferences.
#
# Currently stores the default UI locale used when a request does not include a
# supported +locale+ query parameter. Settings are managed from
# +Settings::ApplicationSettingsController+ and consumed by
# +ApplicationController#set_locale+.
#
# The record is cached under +CACHE_KEY+ so regular requests do not hit the
# database. The cache is expired only after the surrounding transaction commits.
class ApplicationSetting < ApplicationRecord
  # Cache key for the singleton settings record.
  CACHE_KEY = 'application_setting_current'

  # Values used when the singleton row has not been created yet.
  DEFAULTS = { default_locale: 'en' }.freeze

  validates :default_locale,
            presence: true,
            inclusion: { in: SalaryManagement::SUPPORTED_LOCALES.map(&:to_s) }

  after_commit :expire_cache

  # Returns the cached singleton settings row, creating it from the defaults the
  # first time it is needed.
  #
  # @return [ApplicationSetting]
  def self.current
    Rails.cache.fetch(CACHE_KEY) do
      order(:id).first || create!(DEFAULTS)
    end
  end

  # Returns the persisted default locale.
  #
  # Delegates to {.current} so every lookup uses the same cached singleton row
  # and a saved value is visible immediately after the next request.
  #
  # @return [String] one of +SalaryManagement::SUPPORTED_LOCALES+
  def self.default_locale
    current.default_locale
  end

  private

  # Removes the cached singleton after the database transaction commits so the
  # next lookup reads the fresh value.
  #
  # @return [void]
  def expire_cache
    Rails.cache.delete(CACHE_KEY)
  end
end
