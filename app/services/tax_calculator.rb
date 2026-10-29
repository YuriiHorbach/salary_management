# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

class TaxCalculator
  def self.call(**args)
    new(**args).call
  end

  # Rates and thresholds default to the persisted TaxSetting singleton. Callers
  # may still override any of them explicitly (useful for historical results) or
  # pass a preloaded +settings+ record to avoid reloading it for every employee.
  # rubocop:disable Metrics/ParameterLists -- keyword overrides form the public API
  def initialize(amount_cents:, children_count: 0, chaes: false, disability_group: 0, contract: false,
                 psp_uah: nil, psp_invalidity_uah: nil, gran_dohid_uah: nil,
                 income_rate: nil, military_rate: nil, simple: false,
                 ubd: false, single_parent: false, children_disabled_count: 0, settings: nil)
    settings ||= TaxSetting.current

    @amount_cents = amount_cents.to_i
    assign_flags(children_count:, chaes:, disability_group:, contract:, simple:,
                 ubd:, single_parent:, children_disabled_count:)
    assign_settings(settings, psp_uah:, psp_invalidity_uah:, gran_dohid_uah:,
                              income_rate:, military_rate:)
  end
  # rubocop:enable Metrics/ParameterLists

  def call
    return zero_result if @amount_cents <= 0

    gross_cents = @amount_cents
    military_tax_cents = (gross_cents * @military_rate).round

    if @simple || @contract
      income_tax_cents = (gross_cents * @income_rate).round
      return build_result(income_tax_cents, military_tax_cents, gross_cents)
    end

    income_tax_cents = calculate_income_tax(gross_cents)

    build_result(income_tax_cents, military_tax_cents, gross_cents)
  end

  private

  def calculate_income_tax(gross_cents)
    winner = psp_candidates.max_by { |candidate| [candidate[:psp], candidate[:threshold]] }

    return (gross_cents * @income_rate).round if gross_cents > winner[:threshold]

    [((gross_cents - winner[:psp]) * @income_rate).round, 0].max
  end

  # Builds every PSP option and lets the caller pick the most favourable one.
  # Benefits never stack; the winner contributes both its PSP and its threshold.
  def psp_candidates
    base_psp_cents = to_cents(@psp_uah)
    base_threshold_cents = to_cents(@gran_dohid_uah)

    [
      { psp: base_psp_cents, threshold: base_threshold_cents },
      disability_candidate(base_psp_cents, base_threshold_cents),
      children_candidate(base_psp_cents, base_threshold_cents),
      single_parent_candidate(base_psp_cents, base_threshold_cents),
      disabled_children_candidate(base_psp_cents, base_threshold_cents)
    ].compact
  end

  def disability_candidate(base_psp_cents, base_threshold_cents)
    multiplier = disability_multiplier
    return unless multiplier.positive?

    {
      psp: (base_psp_cents * multiplier).round,
      threshold: base_threshold_cents
    }
  end

  def disability_multiplier
    return 2.0 if @ubd
    return 1.5 if @disability_group.positive? || @chaes

    0
  end

  def children_candidate(base_psp_cents, base_threshold_cents)
    return unless @children_count >= 2

    {
      psp: base_psp_cents * @children_count,
      threshold: base_threshold_cents * @children_count
    }
  end

  def single_parent_candidate(base_psp_cents, base_threshold_cents)
    return unless @single_parent && @children_count.positive?

    {
      psp: (base_psp_cents * 1.5 * @children_count).round,
      threshold: base_threshold_cents * @children_count
    }
  end

  def disabled_children_candidate(base_psp_cents, base_threshold_cents)
    return unless @children_disabled_count.positive?

    {
      psp: (base_psp_cents * 1.5 * @children_disabled_count).round,
      threshold: base_threshold_cents * @children_disabled_count
    }
  end

  def assign_flags(children_count:, chaes:, disability_group:, contract:, simple:,
                   ubd:, single_parent:, children_disabled_count:)
    @children_count = children_count.to_i
    @chaes = flag?(chaes)
    @disability_group = disability_group.to_i
    @contract = contract
    @simple = simple
    @ubd = flag?(ubd)
    @single_parent = flag?(single_parent)
    @children_disabled_count = children_disabled_count.to_i
  end

  def assign_settings(settings, psp_uah:, psp_invalidity_uah:, gran_dohid_uah:,
                      income_rate:, military_rate:)
    @psp_uah = to_decimal(psp_uah || settings.psp_uah)
    @psp_invalidity_uah = psp_invalidity_uah ? to_decimal(psp_invalidity_uah) : nil
    @gran_dohid_uah = to_decimal(gran_dohid_uah || settings.gran_dohid_uah)
    @income_rate = to_decimal(income_rate || settings.income_rate)
    @military_rate = to_decimal(military_rate || settings.military_rate)
  end

  def flag?(value)
    !value.nil? && value != false
  end

  def build_result(income_tax_cents, military_tax_cents, gross_cents)
    {
      income_tax_cents: income_tax_cents.to_i,
      military_tax_cents: military_tax_cents.to_i,
      net_amount_cents: (gross_cents - income_tax_cents - military_tax_cents).to_i
    }
  end

  def to_cents(uah_decimal)
    (BigDecimal(uah_decimal.to_s) * 100).to_i
  end

  def to_decimal(value)
    BigDecimal(value.to_s)
  end

  def zero_result
    { income_tax_cents: 0, military_tax_cents: 0, net_amount_cents: 0 }
  end
end
