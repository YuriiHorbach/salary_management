# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaxCalculationJob, type: :job do
  include ActiveJob::TestHelper

  let(:employee) { create(:employee) }
  let(:salary) { create(:salary, employee: employee, amount: 100_000) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    it 'calculates taxes and updates salary record' do
      TaxCalculationJob.perform_now(salary.id)

      salary.reload

      expect(salary.military_tax_cents).to eq 500_000
    end

    it 'enqueues job when salary is created' do
      expect do
        create(:salary, employee: employee)
      end.to have_enqueued_job(TaxCalculationJob)
    end
  end
end
