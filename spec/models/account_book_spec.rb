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

    it 'is valid with proper code format' do
      expect(build(:account_book, code: 'Б11')).to be_valid
      expect(build(:account_book, code: 'О12')).to be_valid
      expect(build(:account_book, code: 'А1')).to be_valid
    end

    it 'rejects a duplicate code' do
      create(:account_book, code: 'Б11')

      expect(build(:account_book, code: 'Б11')).to be_invalid
    end

    it 'normalizes the code before validation' do
      book = build(:account_book, code: ' б11 ')

      expect(book).to be_valid
      expect(book.code).to eq('Б11')
    end
  end

  describe 'associations' do
    it { should have_many(:employees) }
  end

  describe '.available_codes' do
    it 'returns unique codes ordered alphabetically' do
      create(:account_book, code: 'B11')
      create(:account_book, code: 'A1')

      expect(AccountBook.available_codes).to eq(%w[A1 B11])
    end
  end
end
