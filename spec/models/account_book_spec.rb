# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountBook, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:account_book)).to be_valid
    end

    it 'is invalid without code' do
      expect(build(:account_book, code: nil)).to be_invalid
    end

    it 'is invalid with wrong code format' do
      expect(build(:account_book, code: 'invalid')).to be_invalid
    end

    it 'is invalid with duplicate code' do
      create(:account_book, code: 'Б11')
      expect(build(:account_book, code: 'Б11')).to be_invalid
    end

    it 'is valid with proper code format' do
      expect(build(:account_book, code: 'Б11')).to be_valid
      expect(build(:account_book, code: 'О12')).to be_valid
      expect(build(:account_book, code: 'А1')).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:employee).optional }
  end

  describe '#book_code' do
    it 'returns formatted code from book_number and page_number' do
      book = build(:account_book, book_number: 1, page_number: 5)
      expect(book.book_code).to eq('1-5')
    end

    it 'returns nil when book_number is missing' do
      book = build(:account_book, book_number: nil, page_number: 5)
      expect(book.book_code).to be_nil
    end
  end

  describe '#territory_page_code' do
    it 'returns combined territory + book + page code' do
      territory_sign = create(:territory_sign, name: 'Овочева')
      employee = build(:employee, territory_sign: territory_sign)
      book = build(:account_book, employee: employee, book_number: 1, page_number: 1)
      expect(book.territory_page_code).to eq('о11')
    end

    it 'returns nil when no territory sign' do
      book = build(:account_book, book_number: 1, page_number: 1)
      expect(book.territory_page_code).to be_nil
    end
  end
end
