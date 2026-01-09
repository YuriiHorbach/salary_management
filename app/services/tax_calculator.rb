# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

class TaxCalculator
  INCOME_TAX_RATE = BigDecimal('0.18') # 18%
  MILITARY_TAX_RATE = BigDecimal('0.05') # 5%
  GRAN_DOHID_UAH = BigDecimal('4240')    # граничний дохід для ПСП у грн
  PSP_UAH = BigDecimal('1514')            # податкова соціальна пільга (звичайна)

  def self.call(**args)
    new(**args).call
  end

  def initialize(amount_cents:, children_count: 0, chaes: false, disability_group: 0, contract: false,
                 psp_uah: PSP_UAH, psp_invalidity_uah: nil, gran_dohid_uah: GRAN_DOHID_UAH,
                 income_rate: INCOME_TAX_RATE, military_rate: MILITARY_TAX_RATE)
    @amount_cents = amount_cents.to_i
    @children_count = children_count.to_i
    @chaes = !chaes.nil? && chaes != false
    @disability_group = disability_group.to_i
    @contract = contract
    
    @psp_uah = BigDecimal(psp_uah.to_s)
    @psp_invalidity_uah = psp_invalidity_uah ? BigDecimal(psp_invalidity_uah.to_s) : nil
    @gran_dohid_uah = BigDecimal(gran_dohid_uah.to_s)
    @income_rate = BigDecimal(income_rate.to_s)
    @military_rate = BigDecimal(military_rate.to_s)
  end

  def call
    return zero_result if @amount_cents <= 0

    gross_cents = @amount_cents
    military_tax_cents = (gross_cents * @military_rate).round

    if @contract
      income_tax_cents = (gross_cents * @income_rate).round
      return build_result(income_tax_cents, military_tax_cents, gross_cents)
    end

    psp_cents = to_cents(@psp_uah)
    psp_invalidity_cents = @psp_invalidity_uah ? to_cents(@psp_invalidity_uah) : nil
    gran_dohid_cents = to_cents(@gran_dohid_uah)
    
    income_tax_cents = calculate_income_tax(gross_cents, psp_cents, psp_invalidity_cents, gran_dohid_cents)

    build_result(income_tax_cents, military_tax_cents, gross_cents)
  end

  private

  def calculate_income_tax(gross_cents, psp_cents, psp_invalidity_cents, gran_dohid_cents)
    if @children_count >= 2
      child_gran_cents = gran_dohid_cents * @children_count
      return (gross_cents * @income_rate).round if gross_cents > child_gran_cents
      
      tax = ((gross_cents - (psp_cents * @children_count)) * @income_rate).round
      [tax, 0].max

    elsif @disability_group.positive? || @chaes
      psp_to_use = psp_invalidity_cents || psp_cents
      return (gross_cents * @income_rate).round if gross_cents >= gran_dohid_cents
      
      tax = ((gross_cents - psp_to_use) * @income_rate).round
      [tax, 0].max

    elsif gross_cents <= gran_dohid_cents
      tax = ((gross_cents - psp_cents) * @income_rate).round
      [tax, 0].max

    else
      (gross_cents * @income_rate).round
    end
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

  def zero_result
    { income_tax_cents: 0, military_tax_cents: 0, net_amount_cents: 0 }
  end
end