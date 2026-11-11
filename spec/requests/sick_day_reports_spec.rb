# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SickDayReports', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /sick_day_reports' do
    let!(:employee) do
      create(:employee, id_code: '1234567890', last_name: 'Коваленко',
                        first_name: 'Олена', patronic_name: 'Сергіївна')
    end
    let!(:other_employee) do
      create(:employee, id_code: '9876543210', last_name: 'Бондаренко',
                        first_name: 'Олег', patronic_name: 'Іванович')
    end

    before do
      create_list(:sick_day, 2, employee: employee, period: Date.new(2026, 3, 1),
                                pfu_amount: 30, enterprise_amount: 20)
      create(:sick_day, employee: other_employee, period: Date.new(2026, 4, 1),
                        pfu_amount: 10, enterprise_amount: 5)
    end

    def report_row(doc, employee)
      doc.at_css("#sick_day_report_employee_#{employee.id}")
    end

    it 'renders per-employee PFU and enterprise sums for the requested month' do
      get sick_day_reports_path, params: { month: '2026-03' }

      doc = Nokogiri::HTML(response.body)
      row = report_row(doc, employee)

      expect(response).to have_http_status(:ok)
      expect(row.text).to include(employee.full_name)
      expect(row.css('td')[2].text.strip).to eq('60,00')
      expect(row.css('td')[3].text.strip).to eq('40,00')
      expect(row.css('td')[4].text.strip).to eq('100,00')
      expect(doc.text).not_to include(other_employee.full_name)
    end

    it 'renders the grand total for the selected filter month' do
      get sick_day_reports_path, params: { month: '2026-03' }

      total = Nokogiri::HTML(response.body).at_css('#sick_day_report_total')

      expect(total.css('td')[0].text).to include(I18n.t('sick_day_reports.index.total_for', month: '2026-03'))
      expect(total.css('td')[1].text.strip).to eq('60,00')
      expect(total.css('td')[2].text.strip).to eq('40,00')
      expect(total.css('td')[3].text.strip).to eq('100,00')
    end

    it "defaults to the user's current working month" do
      user.update!(current_working_month: Date.new(2026, 3, 1))

      get sick_day_reports_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('input[name="month"]')['value']).to eq('2026-03')
      expect(report_row(doc, employee)).to be_present
    end

    it 'falls back to the current working month for a malformed month param' do
      user.update!(current_working_month: Date.new(2026, 3, 1))

      get sick_day_reports_path, params: { month: 'not-a-month' }

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('input[name="month"]')['value']).to eq('2026-03')
      expect(report_row(doc, employee)).to be_present
    end

    it 'shows an empty state when the month has no sick days' do
      get sick_day_reports_path, params: { month: '2025-01' }

      doc = Nokogiri::HTML(response.body)

      expect(doc.text).to include(I18n.t('sick_day_reports.index.empty'))
      expect(doc.at_css('#sick_day_report_total').css('td')[1].text.strip).to eq('0,00')
    end

    it 'returns only the report frame for turbo frame requests' do
      get sick_day_reports_path, params: { month: '2026-03' }, headers: { 'Turbo-Frame' => 'sick_day_report' }

      expect(response.body).to include('turbo-frame id="sick_day_report"')
      expect(response.body).not_to include('<html')
      expect(response.body).to include(employee.full_name)
    end

    it 'targets the report frame from the month filter' do
      get sick_day_reports_path, params: { month: '2026-03' }

      form = Nokogiri::HTML(response.body).at_css('form[data-turbo-frame="sick_day_report"]')

      expect(form).to be_present
    end

    it 'shows the employee id code linking to the employee page' do
      get sick_day_reports_path, params: { month: '2026-03' }

      row = report_row(Nokogiri::HTML(response.body), employee)
      link = row.at_css("a[href='#{employee_path(employee)}']")

      expect(link.text.strip).to eq(employee.id_code)
      expect(link['data-turbo-frame']).to eq('_top')
    end

    it 'renders an edit button for each employee row' do
      get sick_day_reports_path, params: { month: '2026-03' }

      row = report_row(Nokogiri::HTML(response.body), employee)
      link = row.at_css("a[href='#{employee_sick_days_path(employee)}']")

      expect(link.text.strip).to eq(I18n.t('common.edit'))
      expect(link['class']).to include('btn', 'btn-primary')
      expect(link['data-turbo-frame']).to eq('_top')
    end
  end
end
