# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VacationEntries', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /vacation_entries/new' do
    let!(:petrenko) do
      create(:employee, id_code: '1234567890', last_name: 'Петренко',
                        first_name: 'Іван', patronic_name: 'Іванович')
    end
    let!(:ivanenko) do
      create(:employee, id_code: '9876543210', last_name: 'Іваненко',
                        first_name: 'Марія', patronic_name: 'Петрівна')
    end

    it 'returns a successful response' do
      get new_vacation_entry_path

      expect(response).to have_http_status(:ok)
    end

    it 'renders the employee dropdown, the search field and the vacation inputs' do
      get new_vacation_entry_path

      doc = Nokogiri::HTML(response.body)
      select = doc.at_css('select[name="vacation[employee_id]"]')

      expect(doc.at_css('input[name="employee_search"]')).to be_present
      expect(select).to be_present
      expect(select.text).to include(petrenko.id_code.to_s, petrenko.last_name)
      expect(select.text).to include(ivanenko.id_code.to_s, ivanenko.last_name)
      expect(doc.at_css('input[name="vacation[period]"]')).to be_present
      expect(doc.at_css('input[name="vacation[vacation_amount]"]')).to be_present
    end

    it 'filters the employee dropdown by a case-insensitive name search' do
      get new_vacation_entry_path(employee_search: 'петренко')

      select = Nokogiri::HTML(response.body).at_css('select[name="vacation[employee_id]"]')

      expect(select.text).to include(petrenko.id_code.to_s)
      expect(select.text).not_to include(ivanenko.id_code.to_s)
    end

    it 'filters the employee dropdown by a partial id code' do
      get new_vacation_entry_path(employee_search: '98765')

      select = Nokogiri::HTML(response.body).at_css('select[name="vacation[employee_id]"]')

      expect(select.text).to include(ivanenko.id_code.to_s)
      expect(select.text).not_to include(petrenko.id_code.to_s)
    end

    it 'keeps the search term after filtering' do
      get new_vacation_entry_path(employee_search: 'петренко')

      expect(response.body).to include('value="петренко"')
    end

    it 'does not prefill the vacation amount and shows the input format hint' do
      get new_vacation_entry_path

      amount_input = Nokogiri::HTML(response.body).at_css('input[name="vacation[vacation_amount]"]')

      expect(amount_input['value']).to be_blank
      expect(response.body).to include('1000,00')
    end

    it 'renders the link in the additional navigation menu' do
      get root_path

      expect(response.body).to include(new_vacation_entry_path)
      expect(response.body).to include('Відпустки')
    end
  end

  describe 'POST /vacation_entries' do
    let(:employee) { create(:employee) }

    it 'creates a vacation for the selected employee and redirects to their vacations' do
      expect do
        post vacation_entries_path, params: {
          employee_search: employee.last_name,
          vacation: { employee_id: employee.id, period: '2026-10-01', vacation_amount: '100.00' }
        }
      end.to change(Vacation, :count).by(1)

      vacation = Vacation.last
      expect(vacation.employee).to eq(employee)
      expect(vacation.period).to eq(Date.new(2026, 10, 1))
      expect(vacation.vacation_amount_cents).to eq(10_000)
      expect(vacation.income_tax_cents).to eq(TaxCalculator.call(amount_cents: 10_000, simple: true)[:income_tax_cents])
      expect(response).to redirect_to(employee_vacations_path(employee))
      expect(flash[:notice]).to eq('Відпустку успішно додано.')
    end

    it 'renders the form with an error when no employee is selected' do
      expect do
        post vacation_entries_path, params: {
          vacation: { employee_id: '', period: '2026-10-01', vacation_amount: '100.00' }
        }
      end.not_to change(Vacation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Працівник')
    end

    it 'renders the form with an error when the period is blank' do
      expect do
        post vacation_entries_path, params: {
          vacation: { employee_id: employee.id, period: '', vacation_amount: '100.00' }
        }
      end.not_to change(Vacation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Період')
    end

    it 'keeps the employee search after a failed submission' do
      post vacation_entries_path, params: {
        employee_search: employee.last_name,
        vacation: { employee_id: employee.id, period: '', vacation_amount: '100.00' }
      }

      expect(response.body).to include("value=\"#{employee.last_name}\"")
      expect(response.body).to include(employee.full_name_with_id_code)
    end
  end

  it 'requires authentication' do
    sign_out user

    get new_vacation_entry_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
