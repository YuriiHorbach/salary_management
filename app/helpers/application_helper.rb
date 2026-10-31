# frozen_string_literal: true

# View helpers shared by the whole application, including flash streams and
# locale-aware navigation links.
module ApplicationHelper
  # Complete, JIT-safe Tailwind class strings per flash type.
  #
  # Classes must appear literally in scanned sources (helpers are part of the
  # Tailwind content globs); string interpolation would hide them from the
  # Tailwind scanner and they would never be generated in the built CSS.
  FLASH_CLASSES = {
    'notice' => 'mb-4 rounded-lg bg-blue-100 p-4 text-sm text-blue-700',
    'alert' => 'mb-4 rounded-lg bg-red-100 p-4 text-sm text-red-700'
  }.freeze

  # Neutral fallback for flash types without a dedicated style.
  DEFAULT_FLASH_CLASSES = 'mb-4 rounded-lg bg-gray-100 p-4 text-sm text-gray-800'

  # Tailwind classes for a flash message.
  #
  # @param type [String, Symbol] flash key (+notice+, +alert+, …)
  # @return [String] complete Tailwind class list safe for the JIT scanner
  def flash_classes(type)
    FLASH_CLASSES.fetch(type.to_s, DEFAULT_FLASH_CLASSES)
  end

  # Builds a Turbo Stream that prepends the shared flash partial.
  #
  # @return [Turbo::Streams::TagBuilder] stream containing the flash partial
  def prepend_flash
    turbo_stream.prepend 'flash', partial: 'shared/flash'
  end

  # Returns the only locales the application can render.
  #
  # Uses an explicit application constant instead of +I18n.available_locales+,
  # because development-only gems can add extra YAML files to the I18n load
  # path and otherwise pollute the language switcher.
  #
  # @return [Array<Symbol>] supported locale identifiers
  def supported_locales
    SalaryManagement::SUPPORTED_LOCALES
  end

  # Returns the current page in the requested locale while preserving the
  # current route parameters and query string.
  #
  # @param locale [Symbol, String] target locale
  # @return [String] relative path with the locale query parameter
  def locale_switch_path(locale)
    url_for(request.path_parameters.merge(request.query_parameters).merge(locale: locale, only_path: true))
  end

  # Tailwind classes for the locale switcher links.
  #
  # @param locale [Symbol, String] locale rendered by the link
  # @return [String] CSS classes reflecting the active locale
  def locale_link_classes(locale)
    base = 'rounded px-2 py-1 text-xs font-semibold uppercase transition'
    active = I18n.locale.to_s == locale.to_s

    active ? "#{base} bg-white text-blue-700" : "#{base} text-white hover:bg-blue-600"
  end
end
