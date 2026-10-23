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

    it 'filters the employee list by name case-insensitively' do
      get new_vacation_entry_path(employee_search: 'петренко')

      doc = Nokogiri::HTML(response.body)

      expect(doc.text).to include(petrenko.full_name_with_id_code)
      expect(doc.text).not_to include(ivanenko.full_name_with_id_code)
    end

    it 'shows employees matching a partial id code as selectable options' do
      get new_vacation_entry_path(employee_search: '9876')

      doc = Nokogiri::HTML(response.body)
      radio_values = doc.css('input[type="radio"][name="vacation[employee_id]"]').map { |radio| radio['value'] }

      expect(radio_values).to eq([ivanenko.id.to_s])
      expect(doc.text).to include(ivanenko.full_name_with_id_code)
      expect(doc.text).not_to include(petrenko.full_name_with_id_code)
    end

    it 'shows a passport book id code match typed in lowercase' do
      passport_employee = create(:employee, id_code: 'АА123456', last_name: 'Шевченко',
                                            first_name: 'Тарас', patronic_name: 'Григорович')

      get new_vacation_entry_path(employee_search: 'аа12')

      doc = Nokogiri::HTML(response.body)

      expect(doc.text).to include(passport_employee.full_name_with_id_code)
      expect(doc.text).not_to include(petrenko.full_name_with_id_code, ivanenko.full_name_with_id_code)
    end

    it 'ignores whitespace around a partial id code' do
      get new_vacation_entry_path(employee_search: '  9876  ')

      doc = Nokogiri::HTML(response.body)

      expect(doc.text).to include(ivanenko.full_name_with_id_code)
      expect(doc.text).not_to include(petrenko.full_name_with_id_code)
    end

    it 'shows how many employees matched the partial id code' do
      get new_vacation_entry_path(employee_search: '9876')

      count = Nokogiri::HTML(response.body).at_css('#vacation_employee_search_count')

      expect(count.text.strip).to eq('1')
    end

    it 'shows an empty state when no employee matches' do
      get new_vacation_entry_path(employee_search: '0000')

      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css('#vacation_employee_search_count').text.strip).to eq('0')
      expect(doc.text).to include(I18n.t('common.no_matches'))
    end

    it 'keeps the search term after filtering' do
      get new_vacation_entry_path(employee_search: 'петренко')

      input = Nokogiri::HTML(response.body).at_css('input[name="employee_search"]')

      expect(input['value']).to eq('петренко')
    end

    it 'does not prefill the vacation amount and shows the input format hint' do
      get new_vacation_entry_path

      amount_input = Nokogiri::HTML(response.body).at_css('input[name="vacation[vacation_amount]"]')

      expect(amount_input['value']).to be_blank
      expect(response.body).to include(I18n.t('common.example'))
    end

    it 'renders the link in the additional navigation menu' do
      get root_path

      expect(response.body).to include(new_vacation_entry_path)
      expect(response.body).to include(I18n.t('navigation.vacations'))
    end

    context 'when a current working month is selected' do
      let(:user) { create(:user, current_working_month: Date.new(2025, 4, 1)) }

      it 'defaults the vacation period to the current working month' do
        get new_vacation_entry_path

        period_input = Nokogiri::HTML(response.body).at_css('input[name="vacation[period]"]')

        expect(period_input['value']).to eq('2025-04-01')
      end
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
      expect(flash[:notice]).to eq(I18n.t('flash.vacation_entries.created'))
    end

    it 'renders the form with an error when no employee is selected' do
      expect do
        post vacation_entries_path, params: {
          vacation: { employee_id: '', period: '2026-10-01', vacation_amount: '100.00' }
        }
      end.not_to change(Vacation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('common.employee'))
    end

    it 'renders the form with an error when the period is blank' do
      expect do
        post vacation_entries_path, params: {
          vacation: { employee_id: employee.id, period: '', vacation_amount: '100.00' }
        }
      end.not_to change(Vacation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('common.period'))
    end

    it 're-selects the chosen employee when a different validation fails' do
      post vacation_entries_path, params: {
        vacation: { employee_id: employee.id, period: '', vacation_amount: '100.00' }
      }

      expect(response).to have_http_status(:unprocessable_content)

      select = Nokogiri::HTML(response.body).at_css('select[name="vacation[employee_id]"]')
      selected_values = select.css('option[selected]').map { |option| option['value'] }

      expect(selected_values).to include(employee.id.to_s)
    end

    it 'keeps the partially filtered employee list after a failed create' do
      matching_employee = create(:employee, id_code: '9876543210')
      non_matching_employee = create(:employee, id_code: '1111111111')

      post vacation_entries_path, params: {
        employee_search: '9876',
        vacation: { employee_id: matching_employee.id, period: '', vacation_amount: '100.00' }
      }

      doc = Nokogiri::HTML(response.body)
      selected_radio = doc.at_css(
        "input[type='radio'][name='vacation[employee_id]'][value='#{matching_employee.id}'][checked]"
      )
      expect(selected_radio).to be_present
      expect(doc.text).to include(matching_employee.full_name_with_id_code)
      expect(doc.text).not_to include(non_matching_employee.full_name_with_id_code)
    end

    it 'keeps the search filter after a failed create' do
      post vacation_entries_path, params: {
        employee_search: '1234',
        vacation: { employee_id: employee.id, period: '', vacation_amount: '100.00' }
      }

      input = Nokogiri::HTML(response.body).at_css('input[name="employee_search"]')

      expect(input['value']).to eq('1234')
    end
  end

  it 'requires authentication' do
    sign_out user

    get new_vacation_entry_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
