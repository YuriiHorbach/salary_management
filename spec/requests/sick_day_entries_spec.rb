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

    it 'filters the employee list by name case-insensitively' do
      get new_sick_day_entry_path, params: { employee_search: 'петренко' }

      doc = Nokogiri::HTML(response.body)

      expect(doc.text).to include(petrenko.full_name_with_id_code)
      expect(doc.text).not_to include(ivanenko.full_name_with_id_code)
    end

    it 'shows employees matching a partial id code as selectable options' do
      get new_sick_day_entry_path, params: { employee_search: '9876' }

      doc = Nokogiri::HTML(response.body)
      radio_values = doc.css('input[type="radio"][name="sick_day[employee_id]"]').map { |radio| radio['value'] }

      expect(radio_values).to eq([ivanenko.id.to_s])
      expect(doc.text).to include(ivanenko.full_name_with_id_code)
      expect(doc.text).not_to include(petrenko.full_name_with_id_code)
    end

    it 'shows a passport book id code match typed in lowercase' do
      passport_employee = create(:employee, id_code: 'АА123456', last_name: 'Шевченко',
                                            first_name: 'Тарас', patronic_name: 'Григорович')

      get new_sick_day_entry_path, params: { employee_search: 'аа12' }

      doc = Nokogiri::HTML(response.body)

      expect(doc.text).to include(passport_employee.full_name_with_id_code)
      expect(doc.text).not_to include(petrenko.full_name_with_id_code, ivanenko.full_name_with_id_code)
    end

    it 'ignores whitespace around a partial id code' do
      get new_sick_day_entry_path, params: { employee_search: '  9876  ' }

      doc = Nokogiri::HTML(response.body)

      expect(doc.text).to include(ivanenko.full_name_with_id_code)
      expect(doc.text).not_to include(petrenko.full_name_with_id_code)
    end

    it 'shows how many employees matched the partial id code' do
      get new_sick_day_entry_path, params: { employee_search: '9876' }

      count = Nokogiri::HTML(response.body).at_css('#sick_day_employee_search_count')

      expect(count.text.strip).to eq('1')
    end

    it 'shows an empty state when no employee matches' do
      get new_sick_day_entry_path, params: { employee_search: '0000' }

      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css('#sick_day_employee_search_count').text.strip).to eq('0')
      expect(doc.text).to include(I18n.t('common.no_matches'))
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

      expect(link.text.strip).to eq(I18n.t('navigation.sick_days'))
      expect(doc.text).to include(I18n.t('navigation.more'))
    end

    describe 'embedded sick day report' do
      def report_frame(doc)
        doc.at_css('turbo-frame#sick_day_report')
      end

      it 'renders a turbo frame pointing at the report for the working month' do
        get new_sick_day_entry_path

        frame = report_frame(Nokogiri::HTML(response.body))

        expect(frame).to be_present
        expect(frame['src']).to include(sick_day_reports_path(month: Date.current.strftime('%Y-%m')))
      end

      it 'uses the month param for the embedded report' do
        get new_sick_day_entry_path, params: { month: '2026-03' }

        frame = report_frame(Nokogiri::HTML(response.body))

        expect(frame['src']).to include(sick_day_reports_path(month: '2026-03'))
      end

      it "uses the user's current working month for the embedded report" do
        user.update!(current_working_month: Date.new(2025, 4, 1))

        get new_sick_day_entry_path

        frame = report_frame(Nokogiri::HTML(response.body))

        expect(frame['src']).to include(sick_day_reports_path(month: '2025-04'))
      end
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
          period: Date.current.strftime('%Y-%m'),
          pfu_amount: '60.00',
          enterprise_amount: '40.00'
        }
      }
    end

    it 'creates a sick day for the selected employee and redirects back to the entry page' do
      expect { post sick_day_entries_path, params: valid_params }.to change(SickDay, :count).by(1)

      expect(response).to redirect_to(new_sick_day_entry_path(month: Date.current.strftime('%Y-%m')))

      expect(SickDay.last).to have_attributes(
        employee: employee,
        period: Date.current.beginning_of_month,
        pfu_amount_cents: 6_000,
        enterprise_amount_cents: 4_000,
        income_tax_cents: 1_800,
        military_tax_cents: 500,
        net_amount_cents: 7_700
      )
    end

    it 'points the embedded report at the created month after redirect' do
      post sick_day_entries_path, params: valid_params
      follow_redirect!

      frame = Nokogiri::HTML(response.body).at_css('turbo-frame#sick_day_report')

      expect(frame['src']).to include(sick_day_reports_path(month: Date.current.strftime('%Y-%m')))
    end

    it 'points the embedded report at a non-working month after redirect' do
      user.update!(current_working_month: Date.new(2025, 4, 1))
      params = valid_params.deep_merge(sick_day: { period: '2026-03' })

      post sick_day_entries_path, params: params
      follow_redirect!

      frame = Nokogiri::HTML(response.body).at_css('turbo-frame#sick_day_report')

      expect(frame['src']).to include(sick_day_reports_path(month: '2026-03'))
    end

    it 'reports an error instead of crashing when the amount is too large' do
      expect do
        post sick_day_entries_path, params: {
          sick_day: {
            employee_id: employee.id,
            period: Date.current.strftime('%Y-%m'),
            pfu_amount: '111111111111.00'
          }
        }
      end.not_to change(SickDay, :count)

      expect(response).to have_http_status(:unprocessable_content)

      message = I18n.t('activerecord.errors.models.sick_day.attributes.pfu_amount.amount_too_large').delete_prefix('^')
      attribute = I18n.t('activerecord.attributes.sick_day.pfu_amount')

      expect(response.body).to include(message)
      expect(response.body).not_to include("#{attribute} #{message}")
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

    it 'keeps the partially filtered employee list after a failed create' do
      matching_employee = create(:employee, id_code: '9876543210')
      non_matching_employee = create(:employee, id_code: '1111111111')

      post sick_day_entries_path, params: {
        employee_search: '9876',
        sick_day: { employee_id: matching_employee.id, period: '', pfu_amount: '10.00' }
      }

      doc = Nokogiri::HTML(response.body)
      selected_radio = doc.at_css(
        "input[type='radio'][name='sick_day[employee_id]'][value='#{matching_employee.id}'][checked]"
      )
      expect(selected_radio).to be_present
      expect(doc.text).to include(matching_employee.full_name_with_id_code)
      expect(doc.text).not_to include(non_matching_employee.full_name_with_id_code)
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
