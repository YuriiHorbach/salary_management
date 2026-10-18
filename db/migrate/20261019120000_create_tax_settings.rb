# frozen_string_literal: true

class CreateTaxSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :tax_settings do |t|
      t.decimal :income_rate, precision: 6, scale: 4, null: false
      t.decimal :military_rate, precision: 6, scale: 4, null: false
      t.decimal :gran_dohid_uah, precision: 10, scale: 2, null: false
      t.decimal :psp_uah, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
