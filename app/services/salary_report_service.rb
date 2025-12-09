# frozen_string_literal: true

class SalaryReportService
  def initialize(salary_records)
    @records = salary_records
  end

  def call
    gross = @records.sum(Arel.sql('amount * 100'))
    net = @records.sum(:net_amount_cents)
    pdfo = @records.sum(:income_tax_cents)
    military_tax = @records.sum(:military_tax_cents)

    {
      gross: gross,
      net: net,
      pdfo: pdfo,
      military_tax: military_tax
    }
  end
end
