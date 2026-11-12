# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationSetting, type: :model do
  it { should validate_presence_of(:default_locale) }
  it { should validate_inclusion_of(:default_locale).in_array(%w[en uk de]) }

  describe '.current' do
    it 'creates the singleton row once and reuses it' do
      expect { described_class.current }.to change(described_class, :count).by(1)
      expect(described_class.current).to eq(described_class.order(:id).first)
    end

    it 'reuses the lowest-id row when several rows exist' do
      first_row = described_class.create!(default_locale: 'uk')
      described_class.create!(default_locale: 'de')

      expect(described_class.current).to eq(first_row)
    end
  end

  describe '.default_locale' do
    it 'falls back to English when no settings row exists' do
      expect(described_class.default_locale).to eq('en')
    end

    it 'does not create a settings row' do
      expect { described_class.default_locale }.not_to change(described_class, :count)
    end

    it 'returns the persisted default locale' do
      described_class.create!(default_locale: 'uk')

      expect(described_class.default_locale).to eq('uk')
    end

    it 'reads the same singleton row as .current when several rows exist' do
      described_class.create!(default_locale: 'uk')
      described_class.create!(default_locale: 'de')

      expect(described_class.default_locale).to eq(described_class.current.default_locale)
      expect(described_class.default_locale).to eq('uk')
    end
  end
end
