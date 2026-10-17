# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TerritorySign, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:territory_sign)).to be_valid
    end

    it 'is invalid without name' do
      expect(build(:territory_sign, name: nil)).to be_invalid
    end

    it 'is invalid with duplicate name' do
      create(:territory_sign, name: 'Термінал А')
      expect(build(:territory_sign, name: 'Термінал А')).to be_invalid
    end
  end

  describe 'associations' do
    it { should have_many(:employees).dependent(:nullify) }
  end

  describe '#to_s' do
    it 'returns the name' do
      sign = build(:territory_sign, name: 'Термінал А')
      expect(sign.to_s).to eq('Термінал А')
    end
  end
end
