class SalaryReportService
  def initialize(salary_records)
    @records = salary_records
  end

  def call
    {
      gross: (@records.sum(:amount) * 100).to_i,
      net: @records.sum(:net_amount_cents),
      pdfo: @records.sum(:income_tax_cents),
      military_tax: @records.sum(:military_tax_cents)
    }
  end
end
