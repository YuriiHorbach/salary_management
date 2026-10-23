# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HistoricalDataImporter do
  before { ActiveJob::Base.queue_adapter = :test }

  let!(:employee) { create(:employee, id_code: '1234567890', identifier: 'Б11') }

  def import(csv, type: nil)
    described_class.new(csv, type: type).call
  end

  describe HistoricalDataImporter::CsvTemplate do
    it 'returns a header-only file with every supported column' do
      rows = CSV.parse(described_class.to_csv, headers: true)

      expect(rows).to be_empty
      expect(rows.headers).to include(
        'type', 'id_code', 'identifier', 'period', 'department', 'paid_on',
        'amount', 'pfu_amount', 'enterprise_amount', 'vacation_amount',
        'income_tax', 'military_tax', 'net_amount'
      )
    end
  end

  describe 'salary rows' do
    let(:csv) do
      <<~CSV
        type,id_code,period,amount,income_tax,military_tax,net_amount
        salary,1234567890,2020-03,1000.00,111.00,22.00,867.00
      CSV
    end

    it 'stores the salary for the employee and normalizes the period to the first day of month' do
      import(csv)

      salary = Salary.find_by!(employee: employee, period: Date.new(2020, 3, 1))

      expect(salary.amount_cents).to eq(100_000)
      expect(salary.period).to eq(Date.new(2020, 3, 1))
      expect(salary.paid_on.to_date).to eq(Date.new(2020, 3, 1))
    end

    it 'keeps the imported taxes instead of recalculating them' do
      import(csv)

      salary = Salary.find_by!(employee: employee)

      expect(salary.income_tax_cents).to eq(11_100)
      expect(salary.military_tax_cents).to eq(2_200)
      expect(salary.net_amount_cents).to eq(86_700)
    end

    it 'does not enqueue tax recalculation' do
      expect { import(csv) }.not_to have_enqueued_job(TaxCalculationJob)
    end

    it 'updates an existing salary with the same employee and period' do
      import(csv)

      updated_csv = csv.sub(',1000.00,111.00,22.00,867.00', ',2000.00,222.00,33.00,1745.00')
      result = import(updated_csv)

      expect(result.updated).to eq(1)
      expect(Salary.where(employee: employee).count).to eq(1)

      salary = employee.salaries.first
      expect(salary.amount_cents).to eq(200_000)
      expect(salary.income_tax_cents).to eq(22_200)
    end

    it 'accepts amounts with spaces and a decimal comma' do
      csv = <<~CSV
        id_code,period,amount
        1234567890,2020-07,"1 000,50"
      CSV

      import(csv, type: 'salary')

      expect(employee.salaries.first.amount_cents).to eq(100_050)
    end

    it 'uses zero taxes and derives net pay when tax columns are absent' do
      csv = <<~CSV
        id_code,period,amount
        1234567890,2020-08,1000
      CSV

      import(csv, type: 'salary')

      salary = employee.salaries.first
      expect(salary.income_tax_cents).to eq(0)
      expect(salary.military_tax_cents).to eq(0)
      expect(salary.net_amount_cents).to eq(100_000)
    end

    it 'stores the optional department by name, case-insensitively' do
      department = create(:department, name: 'Бухгалтерія')

      csv = <<~CSV
        id_code,period,amount,department
        1234567890,2020-09,1000,бухгалтерія
      CSV

      import(csv, type: 'salary')

      expect(employee.salaries.first.department).to eq(department)
    end

    it 'accepts the optional department as an id' do
      department = create(:department)

      csv = <<~CSV
        id_code,period,amount,department_id
        1234567890,2020-10,1000,#{department.id}
      CSV

      import(csv, type: 'salary')

      expect(employee.salaries.first.department).to eq(department)
    end

    it 'imports a salary without a department' do
      csv = <<~CSV
        id_code,period,amount
        1234567890,2020-11,1000
      CSV

      import(csv, type: 'salary')

      expect(employee.salaries.first.department_id).to be_nil
    end
  end

  describe 'sick day rows' do
    let(:csv) do
      <<~CSV
        type,id_code,period,pfu_amount,enterprise_amount,income_tax,military_tax,net_amount
        sick_day,1234567890,2020-04,1000,500,111,22,1367
      CSV
    end

    it 'stores the sick day and keeps the imported taxes' do
      import(csv)

      sick_day = SickDay.find_by!(employee: employee, period: Date.new(2020, 4, 1))

      expect(sick_day.pfu_amount_cents).to eq(100_000)
      expect(sick_day.enterprise_amount_cents).to eq(50_000)
      expect(sick_day.income_tax_cents).to eq(11_100)
      expect(sick_day.military_tax_cents).to eq(2_200)
      expect(sick_day.net_amount_cents).to eq(136_700)
    end

    it 'does not recalculate taxes when amounts change on re-import' do
      import(csv)

      updated_csv = csv.sub('1000,500', '2000,700').sub('111,22,1367', '333,44,2323')
      import(updated_csv)

      sick_day = SickDay.find_by!(employee: employee, period: Date.new(2020, 4, 1))
      expect(sick_day.pfu_amount_cents).to eq(200_000)
      expect(sick_day.enterprise_amount_cents).to eq(70_000)
      expect(sick_day.income_tax_cents).to eq(33_300)
      expect(sick_day.military_tax_cents).to eq(4_400)
      expect(SickDay.where(employee: employee).count).to eq(1)
    end

    it 'stores the optional department' do
      department = create(:department, name: 'Відділ кадрів')

      csv = <<~CSV
        type,id_code,period,pfu_amount,enterprise_amount,department
        sick_day,1234567890,2020-06,1000,500,Відділ кадрів
      CSV

      import(csv)

      sick_day = SickDay.find_by!(employee: employee, period: Date.new(2020, 6, 1))
      expect(sick_day.department).to eq(department)
    end
  end

  describe 'vacation rows' do
    let(:csv) do
      <<~CSV
        type,id_code,period,vacation_amount,income_tax,military_tax,net_amount
        vacation,1234567890,2020-05,1000,111,22,867
      CSV
    end

    it 'stores the vacation and keeps the imported taxes' do
      import(csv)

      vacation = Vacation.find_by!(employee: employee, period: Date.new(2020, 5, 1))

      expect(vacation.vacation_amount_cents).to eq(100_000)
      expect(vacation.income_tax_cents).to eq(11_100)
      expect(vacation.military_tax_cents).to eq(2_200)
      expect(vacation.net_amount_cents).to eq(86_700)
    end

    it 'stores the optional department' do
      department = create(:department, name: 'Фінансовий відділ')

      csv = <<~CSV
        type,id_code,period,vacation_amount,department
        vacation,1234567890,2020-12,1000,Фінансовий відділ
      CSV

      import(csv)

      vacation = Vacation.find_by!(employee: employee, period: Date.new(2020, 12, 1))
      expect(vacation.department).to eq(department)
    end
  end

  describe 'mixed file' do
    it 'imports every supported type in one CSV' do
      csv = <<~CSV
        type,id_code,period,amount,pfu_amount,enterprise_amount,vacation_amount,income_tax,military_tax,net_amount
        salary,1234567890,2020-01,1000,,,,100,20,880
        sick_day,1234567890,2020-02,,500,200,,50,10,640
        vacation,1234567890,2020-03,,,,"1 000",100,20,880
      CSV

      result = import(csv)

      expect(result.created).to eq(3)
      expect(Salary.count).to eq(1)
      expect(SickDay.count).to eq(1)
      expect(Vacation.count).to eq(1)
    end
  end

  describe 'period income aggregates' do
    let(:period) { Date.new(2020, 3, 1) }

    def aggregate_for(income_type, period: self.period)
      EmployeePeriodIncome.find_by(employee: employee, period: period, income_type: income_type)
    end

    it 'rebuilds the salary aggregate so imported rows appear in reports' do
      import(<<~CSV)
        type,id_code,period,amount,income_tax,military_tax,net_amount
        salary,1234567890,2020-03,1000,111,22,867
      CSV

      aggregate = aggregate_for('salary')
      expected = TaxCalculator.call(amount_cents: 100_000)

      expect(aggregate).to be_present
      expect(aggregate.gross_cents).to eq(100_000)
      expect(aggregate.income_tax_cents).to eq(expected[:income_tax_cents])
      expect(aggregate.military_tax_cents).to eq(expected[:military_tax_cents])
      expect(aggregate.net_amount_cents).to eq(expected[:net_amount_cents])
    end

    it 'keeps the imported taxes on the record while recalculating the aggregate' do
      import(<<~CSV)
        type,id_code,period,amount,income_tax,military_tax,net_amount
        salary,1234567890,2020-03,1000,111,22,867
      CSV

      salary = Salary.find_by!(employee: employee, period: period)

      expected_tax = TaxCalculator.call(amount_cents: 100_000)[:income_tax_cents]

      expect(salary.income_tax_cents).to eq(11_100)
      expect(salary.military_tax_cents).to eq(2_200)
      expect(aggregate_for('salary').income_tax_cents).to eq(expected_tax)
    end

    it 'rebuilds an aggregate for each type in a mixed file' do
      import(<<~CSV)
        type,id_code,period,amount,pfu_amount,enterprise_amount,vacation_amount
        salary,1234567890,2020-01,1000,,,
        sick_day,1234567890,2020-02,,500,200,
        vacation,1234567890,2020-03,,,,"1 000"
      CSV

      expect(aggregate_for('salary', period: Date.new(2020, 1, 1)).gross_cents).to eq(100_000)
      expect(aggregate_for('sick_day', period: Date.new(2020, 2, 1)).gross_cents).to eq(70_000)
      expect(aggregate_for('vacation').gross_cents).to eq(100_000)
    end

    it 'recalculates the aggregate when a re-import changes the amount' do
      csv = <<~CSV
        type,id_code,period,amount
        salary,1234567890,2020-03,1000
      CSV

      import(csv)
      import(csv.sub(',1000', ',2000'))

      expect(aggregate_for('salary').gross_cents).to eq(200_000)
    end

    context 'when salaries are split across departments' do
      let!(:accounting) { create(:department, name: 'Бухгалтерія') }
      let!(:sales) { create(:department, name: 'Продажі') }
      let(:two_departments_csv) do
        <<~CSV
          type,id_code,period,amount,department
          salary,1234567890,2020-03,1000,Бухгалтерія
          salary,1234567890,2020-03,2000,Продажі
        CSV
      end

      it 'creates one salary per department in the same period instead of overwriting' do
        result = import(two_departments_csv)

        expect(result.created).to eq(2)
        expect(employee.salaries.where(period: period).pluck(:department_id, :amount_cents))
          .to contain_exactly([accounting.id, 100_000], [sales.id, 200_000])
        expect(aggregate_for('salary').gross_cents).to eq(300_000)
      end

      it 'updates only the salary of the matching department on re-import' do
        import(two_departments_csv)

        result = import(<<~CSV)
          type,id_code,period,amount,department
          salary,1234567890,2020-03,1500,Бухгалтерія
        CSV

        expect(result.updated).to eq(1)
        expect(result.created).to eq(0)
        expect(employee.salaries.where(period: period).sum(:amount_cents)).to eq(350_000)
        expect(aggregate_for('salary').gross_cents).to eq(350_000)
      end
    end

    it 'keeps sick days from different departments in the same period' do
      create(:department, name: 'Відділ кадрів')
      create(:department, name: 'Фінансовий відділ')

      result = import(<<~CSV)
        type,id_code,period,pfu_amount,enterprise_amount,department
        sick_day,1234567890,2020-04,500,200,Відділ кадрів
        sick_day,1234567890,2020-04,300,100,Фінансовий відділ
      CSV

      expect(result.created).to eq(2)
      expect(SickDay.where(employee: employee).count).to eq(2)
      expect(aggregate_for('sick_day', period: Date.new(2020, 4, 1)).gross_cents).to eq(110_000)
    end
  end

  describe 'employee matching' do
    it 'finds an employee by a passport-format id code' do
      create(:employee, id_code: 'АА123456')

      csv = <<~CSV
        id_code,period,amount
        аа123456,2020-01,1000
      CSV

      expect(import(csv, type: 'salary').created).to eq(1)
    end

    it 'falls back to the employee book identifier' do
      csv = <<~CSV
        identifier,period,amount
        Б11,2020-01,1000
      CSV

      expect(import(csv, type: 'salary').created).to eq(1)
      expect(employee.salaries.count).to eq(1)
    end
  end

  describe 'invalid rows' do
    it 'skips rows with an unknown employee and reports an error' do
      csv = <<~CSV
        id_code,period,amount
        9999999999,2020-01,1000
      CSV

      result = import(csv, type: 'salary')

      expect(result.created).to eq(0)
      expect(result.skipped).to eq(1)
      expect(result.errors.first).to include('9999999999')
    end

    it 'skips rows with an invalid period' do
      csv = <<~CSV
        id_code,period,amount
        1234567890,not-a-date,1000
      CSV

      result = import(csv, type: 'salary')

      expect(result.created).to eq(0)
      expect(result.skipped).to eq(1)
      expect(result.errors.first).to include('period')
    end

    it 'rejects an unsupported data type' do
      csv = <<~CSV
        id_code,period,amount
        1234567890,2020-01,1000
      CSV

      result = import(csv, type: 'unknown')

      expect(result.created).to eq(0)
      expect(result.errors).not_to be_empty
    end
  end
end
