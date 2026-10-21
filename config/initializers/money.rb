# frozen_string_literal: true

MoneyRails.configure do |config|
  # set the default currency
  # config.default_currency = :UAH
  config.default_currency = :USD

  # rounding mode (BigDecimal rounding constant)
  config.rounding_mode = BigDecimal::ROUND_HALF_UP

  # Display amounts without a currency symbol, thousands separator, or
  # trailing-cents omission. The decimal separator is a comma.
  config.symbol = false
  config.no_cents_if_whole = false
  config.default_format = {
    symbol: false,
    no_cents_if_whole: false,
    delimiter: '',
    separator: ','
  }
end
