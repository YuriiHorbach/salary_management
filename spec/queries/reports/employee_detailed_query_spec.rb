# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::EmployeeDetailedQuery do
  let(:expected_column_keys) do
    %i[
      id_code book_code page_number brigade department full_name
      base_salary salary_income_tax salary_military_tax salary_net
      vacation_amount vacation_income_tax vacation_military_tax
      sick_total sick_pdfo sick_military
      gross_vacation gross_vacation_income_tax gross_vacation_military_tax
      total_income total_tax total_military net_pay
    ]
  end

  let(:expected_column_labels) do
    [
      'ІПН', 'Код книги', 'Номер на сторінці', 'Бригада', 'Підрозділ', 'ПІБ',
      'Базова зп', 'зп податок', 'зп вз', 'зп чиста',
      'відпускні', 'відп податок', 'відп вз',
      'лікарняні', 'лік податок', 'лік вз',
      'Брутто зп+відп', 'ПДФО із зп+відп', 'ВЗ із зп+відп',
      'Загальний дохід', 'Загальний податок', 'Загальний вз', 'Чиста виплата'
    ]
  end

  describe '#call' do
    let!(:department) { create(:department, name: 'Відділ A') }

    let!(:brigade1) { create(:territory_sign, name: 'Бригада 1') }
    let!(:brigade2) { create(:territory_sign, name: 'Бригада 2') }

    let!(:emp1) do
      create(:employee,
        id_code: '1234567890',
        first_name: 'Іван',
        last_name: 'Петренко',
        page_number: '1-Б11',
        territory_sign: brigade1)
    end

    let!(:emp2) do
      create(:employee,
        id_code: '2233445566',
        first_name: 'Марія',
        last_name: 'Іваненко',
        page_number: '2-Б12',
        territory_sign: brigade2)
    end

    let!(:dept_emp1) { create(:department_employee, employee: emp1, department: department) }
    let!(:dept_emp2) { create(:department_employee, employee: emp2, department: department) }

    let!(:book1) { create(:account_book, employee: emp1, code: 'Б11') }
    let!(:book2) { create(:account_book, employee: emp2, code: 'Б12') }

    let!(:salary1) do
      create(:salary, employee: emp1, department: department,
        amount_cents: 100_000, income_tax_cents: 18_000, military_tax_cents: 5_000, net_amount_cents: 77_000,
        paid_on: Date.current)
    end

    let!(:salary2) do
      create(:salary, employee: emp2, department: department,
        amount_cents: 150_000, income_tax_cents: 27_000, military_tax_cents: 7_500, net_amount_cents: 115_500,
        paid_on: Date.current)
    end

    let!(:vacation1) do
      create(:vacation, employee: emp1,
        vacation_amount_cents: 30_000, income_tax_cents: 5_400, military_tax_cents: 1_500, net_amount_cents: 23_100,
        period: Date.current)
    end

    let!(:sick_day1) do
      create(:sick_day, employee: emp1,
        pfu_amount_cents: 20_000, enterprise_amount_cents: 10_000, period: Date.current)
    end

    it 'returns employee rows with aggregated breakdown' do
      result = described_class.new.call

      expect(result[:employees].size).to eq(2)

      emp_row = result[:employees].find { |e| e[:id_code] == '1234567890' }
      expect(emp_row).not_to be_nil
      expect(emp_row[:full_name]).to eq('Петренко Іван Testovich')
      expect(emp_row[:brigade]).to eq('Бригада 1')
      expect(emp_row[:department]).to eq('Відділ A')
      expect([emp_row[:book_code], emp_row[:page_number]]).to eq(%w[Б11 1-Б11])
      expect(emp_row[:base_salary]).to eq(1000.00)
      expect(emp_row[:vacation_amount]).to eq(300.00)
      expect(emp_row[:sick_total]).to eq(300.00) # 20000 + 10000 cents = 300 UAH
    end

    it 'calculates taxes on the combined salary and vacation gross and adds sick leave afterwards' do
      emp_row = described_class.new.call[:employees].find { |e| e[:id_code] == '1234567890' }
      combined = TaxCalculator.call(amount_cents: 130_000, children_count: 0, disability_group: 0,
                                    chaes: false, contract: false)
      sick = TaxCalculator.call(amount_cents: 30_000, simple: true)

      expect(emp_row).to include(
        gross_vacation: 1300.00,
        gross_vacation_income_tax: combined[:income_tax_cents] / 100.0,
        gross_vacation_military_tax: combined[:military_tax_cents] / 100.0,
        total_income: 1600.00,
        total_tax: (combined[:income_tax_cents] + sick[:income_tax_cents]) / 100.0,
        total_military: (combined[:military_tax_cents] + sick[:military_tax_cents]) / 100.0,
        net_pay: (combined[:net_amount_cents] + sick[:net_amount_cents]) / 100.0
      )
    end

    it 'does not sum the separately stored salary, vacation and sick-day taxes' do
      result = described_class.new.call
      emp_row = result[:employees].find { |e| e[:id_code] == '1234567890' }

      separate_taxes = emp_row[:salary_income_tax] + emp_row[:vacation_income_tax] + emp_row[:sick_pdfo]

      expect(emp_row[:total_tax]).not_to eq(separate_taxes)
    end

    it 'includes the employee id on every row so it can link to employee pages' do
      result = described_class.new.call

      expect(result[:employees].map { |employee| employee[:employee_id] })
        .to contain_exactly(emp1.id, emp2.id)
    end

    it 'includes totals row' do
      result = described_class.new.call

      expect(result[:totals][:base_salary]).to eq(2500.00) # 1000 + 1500
      expect(result[:totals][:total_income]).to be > 0
    end

    it 'filters by brigade' do
      result = described_class.new(brigade: brigade1.id).call

      expect(result[:employees].size).to eq(1)
      expect(result[:employees].first[:brigade]).to eq('Бригада 1')
    end

    it 'filters by department' do
      result = described_class.new(department: department.id).call

      expect(result[:employees].size).to eq(2)
    end

    it 'filters by account book code' do
      result = described_class.new(account_book: 'Б11').call

      expect(result[:employees].size).to eq(1)
      expect(result[:employees].first[:book_code]).to eq('Б11')
    end

    it 'returns all employees that share the same account book' do
      emp2.update!(account_book: book1)

      result = described_class.new(account_book: 'Б11').call

      expect(result[:employees].map { |e| e[:id_code] }).to contain_exactly('1234567890', '2233445566')
    end

    it 'returns nothing for an account book code that is not assigned to employees' do
      create(:account_book, employee: nil, code: 'Ч1')

      result = described_class.new(account_book: 'Ч1').call

      expect(result[:employees]).to be_empty
    end

    it 'filters by employee search (id_code)' do
      result = described_class.new(employee_search: '1234567890').call

      expect(result[:employees].size).to eq(1)
      expect(result[:employees].first[:id_code]).to eq('1234567890')
    end

    it 'filters by employee search (name)' do
      result = described_class.new(employee_search: 'Марія').call

      expect(result[:employees].size).to eq(1)
      expect(result[:employees].first[:full_name]).to eq('Іваненко Марія Testovich')
    end

    it 'filters by a multi-word full name' do
      result = described_class.new(employee_search: 'Петренко Іван').call

      expect(result[:employees].map { |employee| employee[:id_code] })
        .to contain_exactly('1234567890')
    end

    it 'filters by a multi-word full name case-insensitively' do
      result = described_class.new(employee_search: 'петренко ІВАН').call

      expect(result[:employees].map { |employee| employee[:id_code] })
        .to contain_exactly('1234567890')
    end

    it 'treats LIKE wildcards in the employee search literally' do
      emp1.update!(last_name: '100%')

      result = described_class.new(employee_search: '%').call

      expect(result[:employees].map { |employee| employee[:id_code] })
        .to contain_exactly('1234567890')
    end

    it 'filters by date range' do
      old_salary = create(:salary, employee: emp1, department: department,
        amount_cents: 50_000, income_tax_cents: 9_000, military_tax_cents: 2_500, net_amount_cents: 38_500,
        paid_on: 1.month.ago)

      result = described_class.new(date_from: Date.current.beginning_of_month, date_to: Date.current.end_of_month).call

      emp_row = result[:employees].find { |e| e[:id_code] == '1234567890' }
      # Should not include the old salary
      expect(emp_row[:base_salary]).to eq(1000.00)
    end

    it 'returns empty when no employees match' do
      result = described_class.new(brigade: 999999).call

      expect(result[:employees]).to be_empty
      expect(result[:totals][:base_salary]).to eq(0.0)
    end

    describe 'sorting' do
      it 'sorts by last name ascending by default' do
        result = described_class.new.call

        expect(result[:employees].map { |e| e[:id_code] }).to eq(%w[2233445566 1234567890])
      end

      it 'uses first name and id code to break last-name ties' do
        emp1.update!(last_name: 'Same', first_name: 'Zed')
        emp2.update!(last_name: 'Same', first_name: 'Anna')

        result = described_class.new.call

        expect(result[:employees].map { |e| e[:id_code] }).to eq(%w[2233445566 1234567890])
      end

      it 'sorts numeric columns descending' do
        result = described_class.new(q: { s: 'base_salary desc' }).call

        expect(result[:employees].map { |e| e[:id_code] }).to eq(%w[2233445566 1234567890])
      end

      it 'sorts numeric columns ascending' do
        result = described_class.new(q: { s: 'base_salary asc' }).call

        expect(result[:employees].map { |e| e[:id_code] }).to eq(%w[1234567890 2233445566])
      end

      it 'sorts text columns case-insensitively' do
        emp1.update!(first_name: 'z', last_name: 'apple')
        emp2.update!(first_name: 'y', last_name: 'Banana')

        result = described_class.new(q: { s: 'full_name asc' }).call

        expect(result[:employees].map { |e| e[:full_name] }).to eq(['apple z Testovich', 'Banana y Testovich'])
      end

      it 'sorts by page number ascending and descending' do
        emp1.update!(page_number: '2-Б111')
        emp2.update!(page_number: '1-О11')

        ascending = described_class.new(q: { s: 'page_number asc' }).call
        descending = described_class.new(q: { s: 'page_number desc' }).call

        expect(ascending[:employees].map { |e| e[:page_number] }).to eq(%w[1-О11 2-Б111])
        expect(descending[:employees].map { |e| e[:page_number] }).to eq(%w[2-Б111 1-О11])
      end

      it 'accepts string keys from request params' do
        result = described_class.new('q' => { 's' => 'base_salary desc' }).call

        expect(result[:employees].map { |e| e[:id_code] }).to eq(%w[2233445566 1234567890])
      end

      it 'falls back to the last-name default for an unknown column' do
        result = described_class.new(q: { s: 'not_a_column desc' }).call

        expect(result[:employees].map { |e| e[:id_code] }).to eq(%w[2233445566 1234567890])
      end

      it 'keeps the totals row unchanged' do
        default_totals = described_class.new.call[:totals]
        sorted_totals = described_class.new(q: { s: 'base_salary desc' }).call[:totals]

        expect(sorted_totals).to eq(default_totals)
      end
    end

    describe 'SQL query efficiency' do
      def count_sql_queries(&)
        query_count = 0

        counter = lambda do |event|
          next if %w[SCHEMA CACHE].include?(event.payload[:name])

          query_count += 1
        end

        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)

        query_count
      end

      it 'executes the same number of queries regardless of the employee count' do
        queries_for_two_employees = count_sql_queries { described_class.new.call }

        create_list(:employee, 3)

        queries_for_five_employees = count_sql_queries { described_class.new.call }

        expect(queries_for_five_employees).to eq(queries_for_two_employees)
      end
    end
  end

  describe 'COLUMN_LABELS' do
    it 'defines the columns in the exact order they appear in the report' do
      expect(described_class::COLUMN_LABELS.keys).to eq(expected_column_keys)
    end

    it 'has the expected Ukrainian label for every column' do
      expect(described_class::COLUMN_LABELS.values).to eq(expected_column_labels)
    end

    it 'only references keys that exist in employee_rows and hides vacation_net' do
      create(:employee)

      row_keys = described_class.new.call[:employees].first.keys

      expect(described_class::COLUMN_LABELS.keys - row_keys).to be_empty
      expect(row_keys).to include(:vacation_net)
    end

    it 'lists the six text columns in TEXT_COLUMNS' do
      expect(described_class::TEXT_COLUMNS).to eq(%i[id_code book_code page_number brigade department full_name])
    end

    it 'has a totals key for every numeric column so the totals row never drops one' do
      numeric_columns = described_class::COLUMN_LABELS.keys - described_class::TEXT_COLUMNS

      expect(numeric_columns - described_class::COLUMN_KEYS).to be_empty
    end
  end
end
