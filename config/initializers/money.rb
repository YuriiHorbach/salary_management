# frozen_string_literal: true

MoneyRails.configure do |config|
  # set the default currency
  # config.default_currency = :UAH
  config.default_currency = :USD

  # rounding mode (BigDecimal rounding constant)
  config.rounding_mode = BigDecimal::ROUND_HALF_UP
end
