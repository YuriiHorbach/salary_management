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

  describe 'GET /employees/:id with salary search' do
    let!(:salary_1200_40) { create(:salary, employee: employee, amount_cents: 120_040) }
    let!(:salary_500) { create(:salary, employee: employee, amount_cents: 50_000) }

    it 'finds salary by amount entered in hryvnia format with comma' do
      get employee_path(employee), params: { salary_q: { amount_cents_eq: '1200,40' } }

      expect(response).to have_http_status(:ok)
      found_salaries = assigns(:employee_salaries).values.flatten
      expect(found_salaries).to include(salary_1200_40)
      expect(found_salaries).not_to include(salary_500)
    end

    it 'finds salary by whole number amount' do
      get employee_path(employee), params: { salary_q: { amount_cents_eq: '500' } }

      expect(response).to have_http_status(:ok)
      found_salaries = assigns(:employee_salaries).values.flatten
      expect(found_salaries).to include(salary_500)
      expect(found_salaries).not_to include(salary_1200_40)
    end

    it 'finds salary by amount with two decimal digits' do
      get employee_path(employee), params: { salary_q: { amount_cents_eq: '1200,40' } }

      expect(response).to have_http_status(:ok)
      found_salaries = assigns(:employee_salaries).values.flatten
      expect(found_salaries).to include(salary_1200_40)
    end

    it 'keeps the entered amount in hryvnia in the search input instead of showing cents' do
      get employee_path(employee), params: { salary_q: { amount_cents_eq: '1200' } }

      expect(response).to have_http_status(:ok)
      expect(assigns(:salary_amount_uah)).to eq('1200')
      expect(response.body).to include('value="1200"')
      expect(response.body).not_to include('value="120000"')
    end

    it 'keeps raw hryvnia input with comma for display while querying in cents' do
      get employee_path(employee), params: { salary_q: { amount_cents_eq: '1200,40' } }

      expect(response).to have_http_status(:ok)
      expect(assigns(:salary_amount_uah)).to eq('1200,40')
      expect(response.body).to include('value="1200,40"')
    end

    it 'does not multiply the amount on repeated searches' do
      get employee_path(employee), params: { salary_q: { amount_cents_eq: '1200' } }

      expect(response).to have_http_status(:ok)
      expect(assigns(:salary_amount_uah)).to eq('1200')
      expect(response.body).to include('value="1200"')
    end
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
