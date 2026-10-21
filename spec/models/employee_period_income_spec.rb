# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeePeriodIncome, type: :model do
  let(:employee) { create(:employee) }
  let(:period) { Date.new(2026, 5, 1) }
  let(:attributes) { { employee: employee, period: period, income_type: 'salary', gross_cents: 100_000 } }

  describe 'associations' do
    it { should belong_to(:employee) }
  end

  describe 'validations' do
    it 'allows one row per employee, period and income type' do
      described_class.create!(attributes)

      duplicate = described_class.new(attributes)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:employee_id]).to be_present
    end

    it 'rejects an unknown income type' do
      record = described_class.new(attributes.merge(income_type: 'bonus'))

      expect(record).not_to be_valid
    end
  end

  it 'is removed together with its employee' do
    described_class.create!(attributes)

    expect { employee.destroy! }.to change(described_class, :count).by(-1)
  end
end
