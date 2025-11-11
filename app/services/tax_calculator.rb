# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

# TaxCalculator calculates income tax (PIT) and military tax for a salary in cents.
# It returns a hash with integer cents values: :income_tax_cents, :military_tax_cents, :net_amount_cents
class TaxCalculator
  INCOME_TAX_RATE = BigDecimal('0.18') # 18%
  MILITARY_TAX_RATE = BigDecimal('0.05') # 5%
  GRAN_DOHID_UAH = BigDecimal('4240')     # граничний дохід у грн
  PSP_UAH = BigDecimal('1514')            # податкова соціальна пільга (звичайна)

  def self.call(**args)
    new(**args).call
  end

  def initialize(amount_cents:, children_count: 0, chaes: false, disability_group: 0,
                 psp_uah: PSP_UAH, psp_invalidity_uah: nil, gran_dohid_uah: GRAN_DOHID_UAH,
                 income_rate: INCOME_TAX_RATE, military_rate: MILITARY_TAX_RATE)
    @amount_cents = amount_cents.to_i
    @children_count = children_count.to_i
    @chaes = !chaes.nil?
    @disability_group = disability_group.to_i
    @psp_uah = BigDecimal(psp_uah.to_s)
    @psp_invalidity_uah = psp_invalidity_uah ? BigDecimal(psp_invalidity_uah.to_s) : nil
    @gran_dohid_uah = BigDecimal(gran_dohid_uah.to_s)
    @income_rate = BigDecimal(income_rate.to_s)
    @military_rate = BigDecimal(military_rate.to_s)
  end

  def call
    return zero_result if @amount_cents <= 0

    gross_cents = @amount_cents
    psp_cents = to_cents(@psp_uah)
    psp_invalidity_cents = @psp_invalidity_uah ? to_cents(@psp_invalidity_uah) : nil
    gran_dohid_cents = to_cents(@gran_dohid_uah)

    income_tax_cents = 0

    if @children_count >= 2
      child_gran_cents = gran_dohid_cents * @children_count
      v_pdfo_children = ((gross_cents - psp_cents * @children_count) * @income_rate).round

      income_tax_cents = if v_pdfo_children.negative?
                           0
                         elsif gross_cents <= child_gran_cents
                           v_pdfo_children
                         else
                           (gross_cents * @income_rate).round
                         end

    elsif @disability_group.positive? || @chaes
      psp_invalid = psp_invalidity_cents || psp_cents

      if gross_cents <= psp_invalid # Випадок, де ЗП менше ПСП
        income_tax_cents = 0
      elsif gross_cents < gran_dohid_cents
        income_tax_cents = ((gross_cents - psp_invalid) * @income_rate).round
        if income_tax_cents.negative?
          income_tax_cents = ((gross_cents - psp_cents) * @income_rate).round
          income_tax_cents = 0 if income_tax_cents.negative?
        end
      else
        income_tax_cents = (gross_cents * @income_rate).round
      end

    elsif gross_cents <= gran_dohid_cents
      v_pdfopilga = ((gross_cents - psp_cents) * @income_rate).round
      income_tax_cents = if v_pdfopilga.negative?
                           0
                         else
                           v_pdfopilga
                         end
    else
      income_tax_cents = (gross_cents * @income_rate).round
    end
    military_tax_cents = (gross_cents * @military_rate).round

    net_amount_cents = gross_cents - income_tax_cents - military_tax_cents

    {
      income_tax_cents: income_tax_cents.to_i,
      military_tax_cents: military_tax_cents.to_i,
      net_amount_cents: net_amount_cents.to_i
    }
  end

  private

  def to_cents(uah_decimal)
    (BigDecimal(uah_decimal.to_s) * 100).to_i
  end

  def zero_result
    { income_tax_cents: 0, military_tax_cents: 0, net_amount_cents: 0 }
  end
end
