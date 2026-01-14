class SalaryReportService
  def initialize(salary_records)
    @records = salary_records
  end

  def call
    {
      gross: @records.sum('salaries.amount_cents'),
      income_tax: @records.sum('salaries.income_tax_cents'),
      military_tax: @records.sum('salaries.military_tax_cents'),
      net: @records.sum('salaries.net_amount_cents')
    }
  end
end
