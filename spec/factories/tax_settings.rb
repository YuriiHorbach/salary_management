# frozen_string_literal: true

FactoryBot.define do
  factory :tax_setting do
    income_rate { 0.18 }
    military_rate { 0.05 }
    gran_dohid_uah { 4240 }
    psp_uah { 1514 }
  end
end
