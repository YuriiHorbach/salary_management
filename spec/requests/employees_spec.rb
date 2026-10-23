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

  describe 'GET /employees search' do
    let!(:maslii) do
      create(:employee, last_name: 'Маслій', first_name: 'Володимир', patronic_name: 'Павлович',
                        chaes: nil, contract: false)
    end
    let!(:chaes_employee) { create(:employee, last_name: 'Чорнобиль', chaes: true, contract: false) }
    let!(:contract_employee) { create(:employee, last_name: 'Контрактний', chaes: nil, contract: true) }

    it 'finds an employee by lowercase Cyrillic name when the checkboxes submit 0' do
      get employees_path, params: {
        q: {
          last_name_cont: 'маслій',
          first_name_cont: 'володимир',
          patronic_name_cont: 'павлович',
          chaes_true: '0',
          contract_true: '0'
        }
      }

      expect(response).to have_http_status(:ok)
      expect(assigns(:employees)).to contain_exactly(maslii)
    end

    it 'does not exclude CHAES employees when the CHAES checkbox is unchecked' do
      get employees_path, params: { q: { last_name_cont: 'Чорнобиль', chaes_true: '0', contract_true: '0' } }

      expect(assigns(:employees)).to contain_exactly(chaes_employee)
    end

    it 'filters by CHAES when the checkbox is checked' do
      get employees_path, params: { q: { chaes_true: '1', contract_true: '0' } }

      expect(assigns(:employees)).to contain_exactly(chaes_employee)
    end

    it 'filters by contract when the checkbox is checked' do
      get employees_path, params: { q: { chaes_true: '0', contract_true: '1' } }

      expect(assigns(:employees)).to contain_exactly(contract_employee)
    end
  end

  describe 'GET /employees id code search' do
    let!(:matching_employee) { create(:employee, id_code: '9999999901') }
    let!(:non_matching_employee) { create(:employee, id_code: '8888888802') }

    it 'finds employees by a partial id code' do
      get employees_path, params: { q: { id_code_cont: '99999' } }

      expect(response).to have_http_status(:ok)
      expect(assigns(:employees)).to include(matching_employee)
      expect(assigns(:employees)).not_to include(non_matching_employee)
    end

    it 'ignores surrounding whitespace in the id code fragment' do
      get employees_path, params: { q: { id_code_cont: '  99999  ' } }

      expect(assigns(:employees)).to include(matching_employee)
    end

    it 'finds passport-style id codes typed in lowercase' do
      passport_employee = create(:employee, id_code: 'АА123456')

      get employees_path, params: { q: { id_code_cont: 'аа12' } }

      expect(assigns(:employees)).to include(passport_employee)
    end
  end

  describe 'GET /employees/:id with salary search' do
    let!(:salary_1200_40) do
      create(:salary, employee: employee, amount_cents: 120_040, period: Date.new(2025, 1, 1))
    end
    let!(:salary_500) do
      create(:salary, employee: employee, amount_cents: 50_000, period: Date.new(2025, 2, 1))
    end

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
      expect(response.body).to include('1000,00')
      expect(response.body).not_to include('100000,00')
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

  describe 'POST /employees' do
    it 'creates an employee with a passport book id_code and normalizes it' do
      post employees_path, params: {
        employee: {
          id_code: '  аа123456 ',
          first_name: 'Іван',
          last_name: 'Петренко',
          patronic_name: 'Іванович'
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(Employee.find_by(id_code: 'АА123456')).to be_present
    end

    it 'creates an employee with an id card number and preserves leading zero' do
      post employees_path, params: {
        employee: {
          id_code: '0123456789',
          first_name: 'Марія',
          last_name: 'Іваненко',
          patronic_name: 'Петрівна'
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(Employee.find_by(id_code: '0123456789')).to be_present
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
