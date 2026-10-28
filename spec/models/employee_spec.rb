# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Employee, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:employee)).to be_valid
    end

    it 'is invalid without id_code' do
      expect(build(:employee, id_code: nil)).to be_invalid
    end

    it 'is valid with a 10-digit tax id code' do
      expect(build(:employee, id_code: '1234567890')).to be_valid
    end

    it 'is valid with a 9-digit id card number' do
      expect(build(:employee, id_code: '012345678')).to be_valid
    end

    it 'is valid with a passport book number' do
      expect(build(:employee, id_code: 'АА123456')).to be_valid
    end

    it 'normalizes id_code by stripping whitespace and upcasing letters' do
      employee = build(:employee, id_code: '  аа123456 ')

      employee.valid?

      expect(employee.id_code).to eq('АА123456')
    end

    it 'is invalid when id_code is too short' do
      expect(build(:employee, id_code: '12345678')).to be_invalid
    end

    it 'is invalid when id_code is too long' do
      expect(build(:employee, id_code: '12345678901')).to be_invalid
    end

    it 'is invalid when id_code has unsupported characters' do
      expect(build(:employee, id_code: '12345abcde')).to be_invalid
    end

    it 'is invalid when a passport book number has the wrong number of digits' do
      expect(build(:employee, id_code: 'АА12345')).to be_invalid
    end

    it 'is invalid when id_code duplicates an existing one case-insensitively' do
      create(:employee, id_code: 'АА123456')

      expect(build(:employee, id_code: 'аа123456')).to be_invalid
    end

    it 'is invalid without first_name' do
      expect(build(:employee, first_name: nil)).to be_invalid
    end

    it 'is invalid without last_name' do
      expect(build(:employee, last_name: nil)).to be_invalid
    end

    it 'is invalid without patronic_name' do
      expect(build(:employee, patronic_name: nil)).to be_invalid
    end

    it 'is valid with a page number in page-book format' do
      expect(build(:employee, page_number: '1-Б111')).to be_valid
    end

    it 'is valid without a page number' do
      expect(build(:employee, page_number: nil)).to be_valid
    end

    it 'normalizes page number by stripping whitespace and upcasing the book code' do
      employee = build(:employee, page_number: ' 2-о21 ')

      employee.valid?

      expect(employee.page_number).to eq('2-О21')
    end

    it 'is invalid when page number does not use page-book format' do
      expect(build(:employee, page_number: 'Б111-1')).to be_invalid
    end

    it 'is invalid when page number has no dash' do
      expect(build(:employee, page_number: '1Б111')).to be_invalid
    end
  end

  describe 'id_code storage' do
    it 'preserves leading zeros' do
      employee = create(:employee, id_code: '0123456789')

      expect(employee.reload.id_code).to eq('0123456789')
    end

    it 'stores passport book numbers as text' do
      employee = create(:employee, id_code: 'АА123456')

      expect(employee.reload.id_code).to eq('АА123456')
    end
  end

  describe 'birthday derived from id_code' do
    it 'sets birthday from the first five digits of a 10-digit id code' do
      employee = create(:employee, id_code: '2862103695')

      expect(employee.birthday).to eq(Date.new(1978, 5, 12))
    end

    it 'updates birthday when the id_code changes' do
      employee = create(:employee, id_code: '2862103695')

      employee.update!(id_code: '1234567890')

      expect(employee.reload.birthday).to eq(Date.new(1933, 10, 19))
    end

    it 'leaves birthday empty for a 9-digit id card number' do
      employee = create(:employee, id_code: '012345678')

      expect(employee.birthday).to be_nil
    end

    it 'leaves birthday empty for a passport book number' do
      employee = create(:employee, id_code: 'АА123456')

      expect(employee.birthday).to be_nil
    end

    it 'keeps the existing birthday when the id_code changes to a passport' do
      employee = create(:employee, id_code: '2862103695')

      employee.update!(id_code: 'АА123456')

      expect(employee.reload.birthday).to eq(Date.new(1978, 5, 12))
    end
  end

  describe 'associations' do
    it { should belong_to(:account_book).optional }
    it { should belong_to(:territory_sign).optional }
  end

  describe '#total_salary' do
    let(:employee) { create(:employee) }

    it 'returns 0 if no salaries' do
      expect(employee.total_salary).to eq(0)
    end

    it 'returns sum of salaries' do
      create(:salary, employee: employee, amount_cents: 100_000, period: Date.new(2025, 1, 1))
      create(:salary, employee: employee, amount_cents: 200_000, period: Date.new(2025, 2, 1))

      expect(employee.total_salary).to eq(3000)
    end
  end

  describe '#book_identifier' do
    let(:employee) { create(:employee) }

    it 'returns nil when no account book' do
      expect(employee.book_identifier).to be_nil
    end

    it 'returns the account book code' do
      create(:account_book, employee: employee, code: 'Б11')
      expect(employee.book_identifier).to eq('Б11')
    end
  end

  describe 'auto-generates identifier on save', truncation: true do
    it 'sets identifier from the account book code' do
      employee = create(:employee)
      create(:account_book, employee: employee, code: 'Б11')
      employee.reload
      expect(employee.identifier).to eq('Б11')
    end

    it 'updates identifier when the account book code changes' do
      employee = create(:employee)
      book = create(:account_book, employee: employee, code: 'Б11')

      book.update!(code: 'Б12')
      employee.reload
      expect(employee.identifier).to eq('Б12')
    end

    it 'clears identifier when the account book is unassigned' do
      employee = create(:employee)
      create(:account_book, employee: employee, code: 'Б11')

      employee.update!(account_book: nil)

      expect(employee.reload.identifier).to be_nil
    end
  end

  describe 'recalculates taxes on attribute change', truncation: true do
    let!(:employee) { create(:employee, children_count: 0, contract: false) }
    let!(:salary) { create(:salary, employee: employee, amount_cents: 700_000, created_at: 5.minutes.ago) }

    it 'recalculates taxes when children_count changes' do
      res_old = TaxCalculator.call(
        amount_cents: salary.amount_cents,
        children_count: 0,
        contract: false
      )
      old_tax = res_old[:income_tax_cents]

      employee.update!(children_count: 3)

      res_new = TaxCalculator.call(
        amount_cents: salary.amount_cents,
        children_count: 3,
        contract: false
      )
      new_tax = res_new[:income_tax_cents]

      expect(new_tax).to be < old_tax
    end

    it 'actually updates salary record' do
      TaxCalculationJob.perform_now(salary.id)
      old_tax = salary.reload.income_tax_cents

      employee.update!(children_count: 3)

      TaxCalculationJob.perform_now(salary.id)

      salary.reload

      expect(salary.income_tax_cents).to be < old_tax
      expect(salary.income_tax_cents).to eq(36_144)
    end

    it 'does NOT recalculate taxes when non-tax-affecting attribute changes' do
      TaxCalculationJob.perform_now(salary.id)
      old_tax = salary.reload.income_tax_cents

      perform_enqueued_jobs do
        employee.update!(first_name: 'NewName')
      end

      expect(salary.reload.income_tax_cents).to eq(old_tax)
    end
  end

  describe '.search_by_id_code_or_name' do
    let!(:petrenko) do
      create(:employee, id_code: '1234567890', last_name: 'Петренко',
                        first_name: 'Іван', patronic_name: 'Іванович')
    end
    let!(:ivanenko) do
      create(:employee, id_code: '9876543210', last_name: 'Іваненко',
                        first_name: 'Марія', patronic_name: 'Петрівна')
    end

    it 'matches by last name case-insensitively' do
      expect(described_class.search_by_id_code_or_name('петренко')).to contain_exactly(petrenko)
    end

    it 'matches by first name case-insensitively' do
      expect(described_class.search_by_id_code_or_name('мАрІя')).to contain_exactly(ivanenko)
    end

    it 'matches by patronymic case-insensitively' do
      expect(described_class.search_by_id_code_or_name('петрівна')).to contain_exactly(ivanenko)
    end

    it 'matches by a partial id code' do
      expect(described_class.search_by_id_code_or_name('12345')).to contain_exactly(petrenko)
    end

    it 'returns every employee when the term is blank' do
      expect(described_class.search_by_id_code_or_name(nil)).to contain_exactly(petrenko, ivanenko)
      expect(described_class.search_by_id_code_or_name('  ')).to contain_exactly(petrenko, ivanenko)
    end

    it 'escapes LIKE wildcards so they are treated literally' do
      expect(described_class.search_by_id_code_or_name('%')).to be_empty
    end
  end

  describe '.search_by_text' do
    let!(:petrenko) do
      create(:employee, id_code: '1234567890', last_name: 'Петренко',
                        first_name: 'Іван', patronic_name: 'Іванович')
    end
    let!(:ivanenko) do
      create(:employee, id_code: '9876543210', last_name: 'Іваненко',
                        first_name: 'Марія', patronic_name: 'Петрівна')
    end

    it 'matches by last name case-insensitively' do
      expect(described_class.search_by_text('петренко')).to contain_exactly(petrenko)
    end

    it 'matches by first name case-insensitively' do
      expect(described_class.search_by_text('мАрІя')).to contain_exactly(ivanenko)
    end

    it 'matches by patronymic case-insensitively' do
      expect(described_class.search_by_text('петрівна')).to contain_exactly(ivanenko)
    end

    it 'matches by a partial id code' do
      expect(described_class.search_by_text('12345')).to contain_exactly(petrenko)
    end

    it 'returns none when the term is blank' do
      expect(described_class.search_by_text(nil)).to be_empty
      expect(described_class.search_by_text('  ')).to be_empty
      expect(described_class.search_by_text('')).to be_empty
    end

    it 'escapes LIKE wildcards so they are treated literally' do
      expect(described_class.search_by_text('%')).to be_empty
      expect(described_class.search_by_text('_')).to be_empty
    end

    it 'limits results to 50 records when chained' do
      create_list(:employee, 200, last_name: 'Іванов', first_name: 'Іван', patronic_name: 'Іванович')

      results = described_class.search_by_text('іванов').limit(50)

      expect(results.size).to eq(50)
    end
  end

  describe '#full_name' do
    it 'returns the last name, first name and patronymic in that order' do
      employee = build(:employee, last_name: 'Петренко', first_name: 'Іван', patronic_name: 'Іванович')

      expect(employee.full_name).to eq('Петренко Іван Іванович')
    end
  end

  describe '#full_name_with_id_code' do
    it 'returns the id code followed by the full name' do
      employee = build(:employee, id_code: '1234567890', last_name: 'Петренко',
                                  first_name: 'Іван', patronic_name: 'Іванович')

      expect(employee.full_name_with_id_code).to eq('1234567890 — Петренко Іван Іванович')
    end
  end
end
