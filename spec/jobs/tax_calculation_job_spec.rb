# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaxCalculationJob, type: :job do
  include ActiveJob::TestHelper

  let(:employee) do
    create(
      :employee,
      children_count: 0,
      disability_group: 0,
      chaes: false,
      contract: false
    )
  end

  let!(:salary) do
    create(
      :salary,
      employee: employee,
      amount: 100_000,
      paid_on: Date.today
    )
  end

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    it 'calculates taxes and updates salary record correctly' do
      perform_enqueued_jobs do
        described_class.perform_later(salary.id)
      end

      salary.reload

      expect(salary.income_tax_cents).to be_present
      expect(salary.military_tax_cents).to be_present
      expect(salary.net_amount_cents).to be_present

      expect(salary.income_tax_cents).to eq(0)
      expect(salary.military_tax_cents).to eq(5_000)
      expect(salary.net_amount_cents).to eq(95_000)
    end

    it 'does not crash if salary does not exist' do
      expect do
        perform_enqueued_jobs do
          described_class.perform_later(999_999)
        end
      end.not_to raise_error
    end

    it 'is enqueued when salary is created' do
      expect do
        create(:salary, employee: employee, amount: 500.0)
      end.to have_enqueued_job(described_class)
    end
  end
end
