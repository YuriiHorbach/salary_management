# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Employees update', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:employee) { create(:employee, children_count: 0) }
  let!(:salary) { create(:salary, employee: employee, amount_cents: 300_000) }

  before do
    sign_in user
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'PATCH /employees/:id' do
    it 'recalculates taxes when tax-affecting attributes change' do
      perform_enqueued_jobs { salary.save }
      old_tax = salary.reload.income_tax_cents

      perform_enqueued_jobs do
        patch employee_path(employee), params: {
          employee: {
            children_count: 3
          }
        }
      end

      salary.reload
      expect(response).to have_http_status(:redirect)
      expect(salary.income_tax_cents).to be < old_tax
    end

    it 'does NOT enqueue tax calculation when non-tax attribute changes' do
      expect do
        patch employee_path(employee), params: {
          employee: {
            first_name: 'UpdatedName'
          }
        }
      end.not_to have_enqueued_job(TaxCalculationJob)
    end
  end
end
