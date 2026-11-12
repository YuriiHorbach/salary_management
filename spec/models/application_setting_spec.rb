# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationSetting, type: :model do
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

  before { Rails.cache.clear }

  it { should validate_presence_of(:default_locale) }
  it { should validate_inclusion_of(:default_locale).in_array(%w[en uk de]) }

  describe '.current' do
    it 'creates the singleton row once and reuses it' do
      setting = described_class.current

      expect(described_class.count).to eq(1)
      expect(described_class.current.id).to eq(setting.id)
    end

    it 'reuses the lowest-id row when several rows exist' do
      first_row = described_class.create!(default_locale: 'uk')
      described_class.create!(default_locale: 'de')

      expect(described_class.current).to eq(first_row)
    end

    it 'returns the cached record without additional SQL queries' do
      described_class.current

      expect(count_sql_queries { described_class.current }).to eq(0)
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

    it 'reads the same singleton row as .current when several rows exist' do
      described_class.create!(default_locale: 'uk')
      described_class.create!(default_locale: 'de')

      expect(described_class.default_locale).to eq(described_class.current.default_locale)
      expect(described_class.default_locale).to eq('uk')
    end
  end

  describe 'cache invalidation' do
    it 'expires the cache after create' do
      described_class.current
      described_class.create!(default_locale: 'de')

      expect(Rails.cache.exist?(described_class::CACHE_KEY)).to be(false)
    end

    it 'returns fresh values immediately after update!' do
      setting = described_class.current
      described_class.find(setting.id).update!(default_locale: 'uk')

      expect(described_class.current.default_locale).to eq('uk')
      expect(described_class.default_locale).to eq('uk')
    end

    it 'expires the cache after destroy' do
      setting = described_class.current
      setting.destroy!

      expect(Rails.cache.exist?(described_class::CACHE_KEY)).to be(false)
      expect(described_class.current.default_locale).to eq('en')
    end

    it 'expires the cache only after the surrounding transaction commits' do
      described_class.current

      described_class.transaction do
        described_class.current.update!(default_locale: 'uk')
        expect(Rails.cache.exist?(described_class::CACHE_KEY)).to be(true)
        raise ActiveRecord::Rollback
      end
    end
  end
end
