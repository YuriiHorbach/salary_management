# frozen_string_literal: true

# Tax configuration defaults. You can override these values in credentials or environment
Rails.application.config.x.tax ||= ActiveSupport::OrderedOptions.new
Rails.application.config.x.tax.income_rate = BigDecimal('0.18')
Rails.application.config.x.tax.military_rate = BigDecimal('0.05')
Rails.application.config.x.tax.gran_dohid_uah = BigDecimal('4240')
Rails.application.config.x.tax.psp_uah = BigDecimal('1514')
