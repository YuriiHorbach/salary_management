# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationSetting, type: :model do
  it { should validate_presence_of(:default_locale) }
  it { should validate_inclusion_of(:default_locale).in_array(%w[en uk de]) }

  describe '.current' do
    it 'creates the singleton row once and reuses it' do
      expect { described_class.current }.to change(described_class, :count).by(1)
      expect(described_class.current).to eq(described_class.first)
    end
  end

  describe '.default_locale' do
    it 'falls back to English when no settings row exists' do
      expect(described_class.default_locale).to eq('en')
    end

    it 'returns the persisted default locale' do
      described_class.create!(default_locale: 'uk')

      expect(described_class.default_locale).to eq('uk')
    end
  end
end
