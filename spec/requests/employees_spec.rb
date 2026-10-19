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

  describe 'GET /employees/:id vacation amounts' do
    it 'shows vacation amounts in currency units instead of cents' do
      create(:vacation, employee: employee, period: '2026-02-01', vacation_amount: 1000)

      get employee_path(employee)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('$1,000.00')
      expect(response.body).not_to include('$100,000.00')
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

  describe 'GET /employees/new' do
    it 'shows the book code selector with available codes' do
      create(:account_book, code: 'А11')

      get new_employee_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('А11')
    end
  end

  describe 'GET /employees/:id/edit' do
    it 'shows the book code selector with the current code' do
      create(:account_book, employee: employee, code: 'О11')

      get edit_employee_path(employee)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('О11')
    end
  end

  describe 'book code selection' do
    it 'assigns the selected book code to the employee profile' do
      patch employee_path(employee), params: {
        employee: { account_book_attributes: { code: 'О11' } }
      }

      expect(response).to have_http_status(:redirect)
      employee.reload
      expect(employee.account_book.code).to eq('О11')
      expect(employee.identifier).to eq('О11')
    end

    it 'changes the book code when another code is selected' do
      create(:account_book, employee: employee, code: 'О11')

      patch employee_path(employee), params: {
        employee: { account_book_attributes: { code: 'Б22' } }
      }

      expect(response).to have_http_status(:redirect)
      employee.reload
      expect(employee.account_book.code).to eq('Б22')
      expect(employee.identifier).to eq('Б22')
    end

    it 'keeps the existing book when no code is selected' do
      create(:account_book, employee: employee, code: 'О11')

      patch employee_path(employee), params: {
        employee: { account_book_attributes: { code: '' } }
      }

      expect(response).to have_http_status(:redirect)
      employee.reload
      expect(employee.account_book.code).to eq('О11')
    end
  end
end
