# frozen_string_literal: true

# Money display and input helpers shared by all views.
#
# Every amount in the application is stored as an integer number of cents
# (+amount_cents+ columns). These helpers are the single place that converts
# cents into user-facing values, so views never hand-roll arithmetic.
module MoneyHelper
  # Formats an amount stored in cents as a localized currency string.
  #
  # Uses money-rails formatting (no symbol, comma decimal separator, no
  # thousands delimiter) which renders exactly like the
  # <tt>number_to_currency(cents / 100.0)</tt> calls this helper replaces:
  # +format_money(123_456)+ returns <tt>"1234,56"</tt>.
  #
  # @param cents [Integer, nil] amount in cents; +nil+ is treated as zero
  # @return [String] formatted amount, e.g. <tt>"1234,56"</tt>
  def format_money(cents)
    humanized_money(Money.from_cents(cents.to_i))
  end

  # Converts an amount stored in cents into a numeric hryvnia value.
  #
  # For form inputs (<tt><input type="number"></tt>), which require a dot
  # decimal separator — unlike {#format_money}, which is for display only.
  #
  # @param cents [Integer, nil] amount in cents; +nil+ is treated as zero
  # @return [Float] value in hryvnia, e.g. <tt>1200.4</tt>
  def money_value(cents)
    cents.to_i / 100.0
  end
end
