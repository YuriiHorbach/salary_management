# frozen_string_literal: true

# Persists application-wide preferences that are editable from the settings
# dashboard. The table intentionally stays singleton: the first row is reused.
class CreateApplicationSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :application_settings do |t|
      t.string :default_locale, null: false, default: 'en'
      t.timestamps
    end
  end
end
