# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SickDayEntries', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /sick_day_entries/new' do
    let!(:petrenko) do
      create(:employee, id_code: '1234567890', last_name: 'Петренко',
                        first_name: 'Іван', patronic_name: 'Іванович')
    end
    let!(:ivanenko) do
      create(:employee, id_code: '9876543210', last_name: 'Іваненко',
                        first_name: 'Марія', patronic_name: 'Петрівна')
    end

    it 'returns a successful response' do
      get new_sick_day_entry_path

      expect(response).to have_http_status(:ok)
    end

    it 'renders the employee dropdown, the search field and the sick day inputs' do
      get new_sick_day_entry_path

      doc = Nokogiri::HTML(response.body)
      select = doc.at_css('select[name="sick_day[employee_id]"]')

      expect(doc.at_css('input[name="employee_search"]')).to be_present
      expect(select).to be_present
      expect(select.text).to include(petrenko.id_code.to_s, petrenko.last_name)
      expect(select.text).to include(ivanenko.id_code.to_s, ivanenko.last_name)
      expect(doc.at_css('input[name="sick_day[period]"]')).to be_present
      expect(doc.at_css('input[name="sick_day[pfu_amount]"]')).to be_present
      expect(doc.at_css('input[name="sick_day[enterprise_amount]"]')).to be_present
    end

    it 'filters the dropdown by name case-insensitively' do
      get new_sick_day_entry_path, params: { employee_search: 'петренко' }

      select = Nokogiri::HTML(response.body).at_css('select[name="sick_day[employee_id]"]')

      expect(select.text).to include(petrenko.last_name)
      expect(select.text).not_to include(ivanenko.last_name)
    end

    it 'filters the dropdown by a partial id code' do
      get new_sick_day_entry_path, params: { employee_search: '9876' }

      select = Nokogiri::HTML(response.body).at_css('select[name="sick_day[employee_id]"]')

      expect(select.text).to include(ivanenko.last_name)
      expect(select.text).not_to include(petrenko.last_name)
    end

    it 'keeps the search term in the search field' do
      get new_sick_day_entry_path, params: { employee_search: 'петренко' }

      input = Nokogiri::HTML(response.body).at_css('input[name="employee_search"]')

      expect(input['value']).to eq('петренко')
    end

    it 'renders a link to the standalone sick day form from the additional navigation menu' do
      get new_sick_day_entry_path

      doc = Nokogiri::HTML(response.body)
      link = doc.at_css("a[href='#{new_sick_day_entry_path}']")

      expect(link.text.strip).to eq('Лікарняні')
      expect(doc.text).to include('Додатково')
    end

    context 'when a current working month is selected' do
      let(:user) { create(:user, current_working_month: Date.new(2025, 4, 1)) }

      it 'defaults the sick day period to the current working month' do
        get new_sick_day_entry_path

        period_input = Nokogiri::HTML(response.body).at_css('input[name="sick_day[period]"]')

        expect(period_input['value']).to eq('2025-04')
      end
    end
  end

  describe 'POST /sick_day_entries' do
    let!(:employee) do
      create(:employee, id_code: '1234567890', last_name: 'Петренко',
                        first_name: 'Іван', patronic_name: 'Іванович')
    end
    let(:valid_params) do
      {
        sick_day: {
          employee_id: employee.id,
          period: '2026-10',
          pfu_amount: '60.00',
          enterprise_amount: '40.00'
        }
      }
    end

    it 'creates a sick day for the selected employee and redirects to their sick days list' do
      expect { post sick_day_entries_path, params: valid_params }.to change(SickDay, :count).by(1)

      expect(response).to redirect_to(employee_sick_days_path(employee))

      expect(SickDay.last).to have_attributes(
        employee: employee,
        period: Date.new(2026, 10, 1),
        pfu_amount_cents: 6_000,
        enterprise_amount_cents: 4_000,
        income_tax_cents: 1_800,
        military_tax_cents: 500,
        net_amount_cents: 7_700
      )
    end

    it 'does not create a record without an employee and re-renders with 422' do
      expect do
        post sick_day_entries_path, params: {
          sick_day: { employee_id: '', period: '2026-10', pfu_amount: '10.00' }
        }
      end.not_to change(SickDay, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 're-selects the chosen employee when a different validation fails' do
      post sick_day_entries_path, params: {
        sick_day: { employee_id: employee.id, period: '', pfu_amount: '10.00' }
      }

      expect(response).to have_http_status(:unprocessable_entity)

      select = Nokogiri::HTML(response.body).at_css('select[name="sick_day[employee_id]"]')
      selected_values = select.css('option[selected]').map { |option| option['value'] }

      expect(selected_values).to include(employee.id.to_s)
    end

    it 'keeps the search filter after a failed create' do
      post sick_day_entries_path, params: {
        employee_search: '1234',
        sick_day: { employee_id: employee.id, period: '', pfu_amount: '10.00' }
      }

      input = Nokogiri::HTML(response.body).at_css('input[name="employee_search"]')

      expect(input['value']).to eq('1234')
    end
  end

  describe 'authentication' do
    before { sign_out user }

    it 'redirects to the login page for GET' do
      get new_sick_day_entry_path

      expect(response).to have_http_status(:redirect)
    end

    it 'redirects to the login page for POST' do
      post sick_day_entries_path, params: {
        sick_day: { employee_id: 1, period: '2026-10', pfu_amount: '10.00' }
      }

      expect(response).to have_http_status(:redirect)
    end
  end
end
