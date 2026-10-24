# frozen_string_literal: true

require 'rails_helper'
require 'csv'

FULLY_POPULATED_ROW = [
  '1234567890', 'Б99', 'Бригада X', 'Відділ X', 'Петренко Іван Testovich',
  '1000,00', '0,00', '50,00', '950,00',
  '300,00', '54,00', '15,00',
  '300,00', '54,00', '15,00',
  '1300,00', '1600,00', '108,00', '80,00', '1412,00'
].freeze

RSpec.shared_context 'with a fully populated employee' do
  let(:department) { create(:department, name: 'Відділ X') }
  let(:brigade) { create(:territory_sign, name: 'Бригада X') }
  let(:employee) do
    create(:employee, id_code: '1234567890', first_name: 'Іван', last_name: 'Петренко',
                      territory_sign: brigade, children_count: 0)
  end
  let(:rows) { Nokogiri::HTML(response.body).css('table tbody tr') }
  let!(:salary) do
    create(:salary, employee: employee, department: department, amount_cents: 100_000,
                    income_tax_cents: 18_000, military_tax_cents: 5_000, net_amount_cents: 77_000)
  end

  before do
    create(:account_book, employee: employee, code: 'Б99')
    create(:department_employee, employee: employee, department: department)
    create(:vacation, employee: employee, vacation_amount_cents: 30_000, income_tax_cents: 5_400,
                      military_tax_cents: 1_500, net_amount_cents: 23_100)
    create(:sick_day, employee: employee, pfu_amount_cents: 20_000,
                      enterprise_amount_cents: 10_000, period: Date.current)
    get detailed_reports_path
  end
end

RSpec.describe 'Reports', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:employee) { create(:employee, children_count: 0) }
  let!(:salary) { create(:salary, employee: employee, amount_cents: 300_000) }

  before do
    sign_in user
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'GET /reports' do
    it 'renders money values without currency symbols' do
      get reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('3000,00')
      expect(response.body).not_to include('$3000,00', '₴3000,00', '3000,00 ₴')
    end
  end

  describe 'GET /reports/summary' do
    it 'returns a successful response' do
      get summary_reports_path

      expect(response).to have_http_status(:ok)
    end

    it 'returns aggregated summary data' do
      get summary_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('reports.summary_columns.total_income'))
      expect(response.body).to include(I18n.t('reports.summary_columns.total_tax'))
    end

    it 'splits the first column into separate Brigade and Book headers' do
      get summary_reports_path

      doc = Nokogiri::HTML(response.body)
      headers = doc.css('table thead tr').first.css('th').map { |th| th.text.strip }

      expect(headers.first).to eq(I18n.t('reports.summary.brigade'))
      expect(headers.second).to eq(I18n.t('reports.summary.book'))
      expect(headers).not_to include("#{I18n.t('reports.summary.brigade')} / #{I18n.t('reports.summary.book')}")
    end

    it 'renders one header cell per table column' do
      get summary_reports_path

      doc = Nokogiri::HTML(response.body)
      header_cells = doc.css('table thead tr').first.css('th').size
      first_data_cells = doc.css('table tbody tr').first.css('td').size

      expect(header_cells).to eq(Reports::SalarySummaryQuery::COLUMN_KEYS.size + 2)
      expect(first_data_cells).to eq(header_cells)
    end

    describe 'CSV export button' do
      it 'renders a link to the summary CSV export with the green Tailwind classes' do
        get summary_reports_path

        doc = Nokogiri::HTML(response.body)
        link = doc.at_css('a[href*="/reports/summary.csv"]')

        expect(link).to be_present
        expect(link.text.strip).to eq(I18n.t('reports.summary.export_csv'))
        expect(link['class']).to include('bg-green-600', 'hover:bg-green-700', 'text-white',
                                         'text-sm', 'font-bold', 'py-2', 'px-4', 'rounded')
        expect(link['data-turbo']).to eq('false')
      end

      it 'keeps the selected period in the summary CSV export link' do
        get summary_reports_path, params: { period: '2025-05' }

        doc = Nokogiri::HTML(response.body)
        href = doc.at_css('a[href*="/reports/summary.csv"]')['href']

        expect(href).to include('period=2025-05')
      end

      it 'renders a period filter on the summary report' do
        get summary_reports_path, params: { period: '2025-05' }

        period_input = Nokogiri::HTML(response.body).at_css('input[name="period"]')

        expect(period_input).to be_present
        expect(period_input['value']).to eq('2025-05')
      end
    end

    context 'when requesting CSV' do
      it 'returns a CSV attachment response' do
        get summary_reports_path(format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include("summary-#{Date.current}.csv")
      end

      it 'renders a parseable CSV document' do
        get summary_reports_path(format: :csv)

        rows = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';')

        expect(rows).to be_an(Array)
        expect(rows.first).to be_present
        expect(rows.first.first(2)).to eq([I18n.t('reports.csv.brigade'), I18n.t('reports.csv.book')])
        expect(rows.last.first).to eq(I18n.t('reports.csv.total'))
      end

      it 'keeps the html behavior untouched when no format is given' do
        get summary_reports_path

        expect(response.media_type).to eq('text/html')
      end
    end
  end

  describe 'GET /reports/detailed' do
    it 'returns a successful response' do
      get detailed_reports_path

      expect(response).to have_http_status(:ok)
    end

    it 'renders the detailed report table' do
      get detailed_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('reports.detailed_columns.id_code'))
      expect(response.body).to include(I18n.t('reports.detailed_columns.full_name'))
      expect(response.body).to include('detailed_report_table')
    end

    it 'links the employee ID code to their salary page' do
      get detailed_reports_path

      link = Nokogiri::HTML(response.body).at_css("a[href='#{employee_salaries_path(employee)}']")

      expect(link).to be_present
      expect(link.text.strip).to eq(employee.id_code)
      expect(link['data-turbo-frame']).to eq('_top')
    end

    it 'filters by brigade' do
      get detailed_reports_path, params: { brigade: employee.territory_info }

      expect(response).to have_http_status(:ok)
    end

    it 'filters by date range' do
      get detailed_reports_path,
          params: { date_from: Date.current.beginning_of_month, date_to: Date.current.end_of_month }

      expect(response).to have_http_status(:ok)
    end

    describe 'position filter' do
      let(:filter_department) { create(:department, name: 'Відділ Посад') }
      let(:engineer_position) { create(:position, department: filter_department, position_name: 'Інженер') }
      let(:manager_position) { create(:position, department: filter_department, position_name: 'Менеджер') }
      let(:engineer) do
        create(:employee, id_code: '3333333333', first_name: 'Інженер', last_name: 'Працівник')
      end
      let(:manager) do
        create(:employee, id_code: '4444444444', first_name: 'Менеджер', last_name: 'Працівник')
      end

      def position_filter_report_ids
        rows = Nokogiri::HTML(response.body).css('table tbody tr').select do |row|
          row.css('td').size == Reports::EmployeeDetailedQuery::COLUMN_LABELS.size
        end

        rows.map { |row| row.css('td').first.text.strip }
      end

      before do
        create(:department_employee, employee: engineer, department: filter_department,
                                     position: engineer_position)
        create(:department_employee, employee: manager, department: filter_department,
                                     position: manager_position)
        create(:salary, employee: engineer, department: filter_department)
        create(:salary, employee: manager, department: filter_department)
      end

      it 'filters the detailed report rows by position' do
        get detailed_reports_path(position: engineer_position.id)

        expect(position_filter_report_ids).to include(engineer.id_code.to_s)
        expect(position_filter_report_ids).not_to include(manager.id_code.to_s)
      end

      it 'renders a position selector with the available positions' do
        get detailed_reports_path

        selector = Nokogiri::HTML(response.body).at_css('select[name="position"]')

        expect(selector).to be_present
        expect(selector.text).to include('Інженер', 'Менеджер')
      end

      it 'keeps the position filter in the CSV export link' do
        get detailed_reports_path(position: engineer_position.id)

        href = Nokogiri::HTML(response.body).at_css('a[href*=".csv"]')['href']

        expect(href).to include("position=#{engineer_position.id}")
      end

      it 'filters the CSV export by position' do
        get detailed_reports_path(format: :csv), params: { position: engineer_position.id }

        ids = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';')[1..].map(&:first)

        expect(ids).to include(engineer.id_code.to_s)
        expect(ids).not_to include(manager.id_code.to_s)
      end

      it 'scopes the position filter to the selected department' do
        other_department = create(:department, name: 'Інший відділ')
        create(:department_employee, employee: engineer, department: other_department)

        get detailed_reports_path(department: other_department.id, position: engineer_position.id)

        expect(position_filter_report_ids).not_to include(engineer.id_code.to_s)
      end

      it 'does not duplicate an employee with several positions' do
        create(:department_employee, employee: engineer, department: filter_department,
                                     position: manager_position)

        get detailed_reports_path(position: engineer_position.id)

        expect(position_filter_report_ids.count(engineer.id_code.to_s)).to eq(1)
      end
    end

    it 'renders one header cell per data column so every column has a label' do
      get detailed_reports_path

      doc = Nokogiri::HTML(response.body)
      header_cells = doc.css('table thead tr').first.css('th').size
      first_data_cells = doc.css('table tbody tr').first.css('td').size

      expect(header_cells).to eq(first_data_cells)
    end

    it 'labels the gross salary+vacation and the last net pay columns' do
      get detailed_reports_path

      doc = Nokogiri::HTML(response.body)
      headers = doc.css('table thead tr').first.css('th').map { |th| th.text.strip }

      expect(headers).to include(I18n.t('reports.detailed_columns.gross_vacation'))
      expect(headers.last).to eq(I18n.t('reports.detailed_columns.net_pay'))
    end

    it 'renders the header cells with the exact labels, order and alignment classes' do
      get detailed_reports_path

      doc = Nokogiri::HTML(response.body)
      header_cells = doc.css('table thead tr').first.css('th')

      Reports::EmployeeDetailedQuery::COLUMN_LABELS.each_with_index do |(key, _label), index|
        alignment = Reports::EmployeeDetailedQuery::TEXT_COLUMNS.include?(key) ? 'text-left' : 'text-right'

        expect(header_cells[index].text.strip).to eq(I18n.t("reports.detailed_columns.#{key}"))
        expect(header_cells[index]['class']).to include(alignment)
      end
    end

    it 'renders a single empty-state cell spanning all columns' do
      get detailed_reports_path, params: { brigade: 999_999 }

      doc = Nokogiri::HTML(response.body)
      cells = doc.css('table tbody tr').first.css('td')

      expect(cells.size).to eq(1)
      expect(cells.first['colspan']).to eq('20')
    end

    describe 'sorting' do
      let!(:top_earner) do
        create(:employee, id_code: '9999999999', first_name: 'Найвищий', last_name: 'Оклад')
      end
      let!(:top_earner_salary) { create(:salary, employee: top_earner, amount_cents: 900_000) }

      def header_links
        Nokogiri::HTML(response.body).css('table thead th a')
      end

      def report_id_codes
        rows = Nokogiri::HTML(response.body).css('table tbody tr').select do |row|
          row.css('td').size == Reports::EmployeeDetailedQuery::COLUMN_LABELS.size
        end

        rows.map { |row| row.css('td').first.text.strip }
      end

      def query_params_for(link)
        Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
      end

      it 'sorts rows by last name ascending by default' do
        brigade = create(:territory_sign, name: 'Бригада Сортування за замовчуванням')
        create(:employee, id_code: '1111111111', first_name: 'Anna', last_name: 'Zulu',
                          territory_sign: brigade)
        create(:employee, id_code: '2222222222', first_name: 'Bohdan', last_name: 'Alpha',
                          territory_sign: brigade)

        get detailed_reports_path(brigade: brigade.id)

        expect(report_id_codes).to eq(%w[2222222222 1111111111])
      end

      it 'renders a Ransack sort link in every header cell' do
        get detailed_reports_path

        expect(header_links.size).to eq(Reports::EmployeeDetailedQuery::COLUMN_LABELS.size)
        expect(query_params_for(header_links.first).dig('q', 's')).to eq('id_code asc')
      end

      it 'sorts rows descending by the requested numeric column' do
        get detailed_reports_path, params: { q: { s: 'base_salary desc' } }

        expect(report_id_codes.first).to eq('9999999999')
      end

      it 'sorts rows ascending by the requested numeric column' do
        get detailed_reports_path, params: { q: { s: 'base_salary asc' } }

        expect(report_id_codes.last).to eq('9999999999')
      end

      it 'keeps the active filters in the sort links' do
        brigade = create(:territory_sign, name: 'Бригада Сортування')

        get detailed_reports_path(brigade: brigade.id)

        expect(header_links.first['href']).to include("brigade=#{brigade.id}")
      end

      it 'drops the commit and page params from the sort links' do
        get detailed_reports_path(commit: I18n.t('reports.detailed.filter'), page: 2)

        href = header_links.first['href']

        expect(href).not_to include('commit')
        expect(href).not_to include('page=')
      end

      it 'preserves the active sort in the filter form' do
        get detailed_reports_path(q: { s: 'base_salary desc' })

        hidden = Nokogiri::HTML(response.body).at_css('form input[type="hidden"][name="q[s]"]')

        expect(hidden['value']).to eq('base_salary desc')
      end

      it 'falls back to the default order for an unknown sort column' do
        get detailed_reports_path
        default_ids = report_id_codes

        get detailed_reports_path, params: { q: { s: 'not_a_column desc' } }

        expect(response).to have_http_status(:ok)
        expect(report_id_codes).to eq(default_ids)
      end
    end

    context 'with a fully populated employee' do
      include_context 'with a fully populated employee'

      it 'renders the employee cells in the expected column order' do
        expect(rows.first.css('td').map { |td| td.text.strip }).to eq(FULLY_POPULATED_ROW)
      end

      it 'aligns numeric cells right and emphasises full_name and net_pay' do
        cells = rows.first.css('td')

        expect(cells[4]['class']).to include('font-medium')
        expect(cells[4]['class']).not_to include('text-right')
        expect(cells[5..].pluck('class')).to all(include('text-right'))
        expect(cells[19]['class']).to include('text-right', 'font-semibold')
      end

      it 'renders the totals row with a spanning label and the numeric totals' do
        cells = rows.last.css('td')

        expect(cells.size).to eq(16)
        expect(cells.first['colspan']).to eq('5')
        expect(cells.first.text.strip).to eq(I18n.t('reports.detailed.total'))
        expect(cells[1..].map { |td| td.text.strip }).to eq(FULLY_POPULATED_ROW[5..])
      end
    end

    describe 'CSV export button' do
      let(:brigade) { create(:territory_sign, name: 'Бригада Експорт') }

      it 'renders next to the reset button with the green Tailwind classes' do
        get detailed_reports_path

        doc = Nokogiri::HTML(response.body)
        link = doc.at_css('a[href*=".csv"]')
        reset_link = doc.xpath("//a[normalize-space(text())='#{I18n.t('reports.detailed.reset')}']").first

        expect(link).to be_present
        expect(reset_link).to be_present
        expect(link.parent).to eq(reset_link.parent)
        expect(link.text.strip).to eq(I18n.t('reports.detailed.export_csv'))
        expect(link['class']).to include('bg-green-600', 'hover:bg-green-700', 'text-white',
                                         'text-sm', 'font-bold', 'py-2', 'px-4', 'rounded')
        expect(link['data-turbo']).to eq('false')
      end

      it 'keeps the current filters and drops commit/controller/action from the export link' do
        get detailed_reports_path, params: { brigade: brigade.id }

        doc = Nokogiri::HTML(response.body)
        href = doc.at_css('a[href*=".csv"]')['href']

        expect(href).to include('.csv')
        expect(href).to include("brigade=#{brigade.id}")
        expect(href).not_to include('commit')
        expect(href).not_to include('controller')
        expect(href).not_to include('action')
      end
    end

    context 'when requesting CSV' do
      let(:brigade_one) { create(:territory_sign, name: 'Бригада Один') }
      let(:brigade_two) { create(:territory_sign, name: 'Бригада Два') }
      let(:employee_one) do
        create(:employee, id_code: '1111111111', first_name: 'Перший', last_name: 'Працівник',
                          territory_sign: brigade_one)
      end
      let(:employee_two) do
        create(:employee, id_code: '2222222222', first_name: 'Другий', last_name: 'Працівник',
                          territory_sign: brigade_two)
      end

      let(:csv_rows) { CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';') }
      let(:csv_id_codes) { csv_rows[1..].map(&:first) }

      before do
        create(:salary, employee: employee_one)
        create(:salary, employee: employee_two)
      end

      it 'returns a CSV attachment response with the detailed filename' do
        get detailed_reports_path(format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include("detailed-#{Date.current}.csv")
      end

      it 'renders a parseable CSV document headed by the ID code column' do
        get detailed_reports_path(format: :csv)

        expect(csv_rows).to be_an(Array)
        expect(csv_rows.first.first).to eq(I18n.t('reports.detailed_columns.id_code'))
      end

      it 'includes both employees from different brigades' do
        get detailed_reports_path(format: :csv)

        expect(csv_id_codes).to include('1111111111', '2222222222')
      end

      it 'filters the CSV rows by the brigade parameter' do
        get detailed_reports_path(format: :csv), params: { brigade: brigade_one.id }

        expect(csv_id_codes).to include('1111111111')
        expect(csv_id_codes).not_to include('2222222222')
      end

      it 'keeps the html behavior untouched when no format is given' do
        get detailed_reports_path

        expect(response.media_type).to eq('text/html')
      end
    end
  end

  describe 'GET /reports/detailed pagination' do
    let!(:salary) { nil } # disable the shared salary/employee so the employee count is deterministic
    let(:brigade) { create(:territory_sign, name: 'Бригада Пагінація') }
    let(:department) { create(:department, name: 'Відділ Пагінація') }
    let!(:employees) { create_list(:employee, 25, territory_sign: brigade) }

    def parsed_doc
      Nokogiri::HTML(response.body)
    end

    def employee_rows
      parsed_doc.css('table tbody tr').select do |row|
        row.css('td').size == Reports::EmployeeDetailedQuery::COLUMN_LABELS.size
      end
    end

    def employee_id_codes
      employee_rows.map { |row| row.css('td').first.text.strip }
    end

    def totals_row
      parsed_doc.css('table tbody tr').find do |row|
        row.css('td').size < Reports::EmployeeDetailedQuery::COLUMN_LABELS.size
      end
    end

    it 'shows 20 employees per page' do
      get detailed_reports_path

      expect(employee_rows.size).to eq(20)
    end

    it 'shows the remaining employees on the second page' do
      get detailed_reports_path(page: 2)

      expect(employee_rows.size).to eq(5)
    end

    it 'does not repeat employees across pages' do
      get detailed_reports_path
      first_page_ids = employee_id_codes

      get detailed_reports_path(page: 2)
      second_page_ids = employee_id_codes

      expect(first_page_ids & second_page_ids).to be_empty
      expect((first_page_ids + second_page_ids).sort).to eq(employees.map { |e| e.id_code.to_s }.sort)
    end

    it 'keeps the totals row for all filtered employees, not just the current page' do
      employees.each do |employee|
        create(:salary, employee: employee, department: department, amount_cents: 100_000)
      end

      get detailed_reports_path

      expect(totals_row.text).to include('25000,00')
    end

    it 'renders the pagination navigation inside the report turbo frame' do
      get detailed_reports_path

      frame = parsed_doc.at_css('turbo-frame#detailed_report_table')

      expect(frame).to be_present
      expect(frame.at_css('nav.pagy')).to be_present
      expect(frame.at_css('a[href*="page=2"]')).to be_present
    end

    it 'renders the pagination navigation above the table' do
      get detailed_reports_path

      frame = parsed_doc.at_css('turbo-frame#detailed_report_table')
      top_pagination = frame.at_css('#detailed_report_pagination_top')

      expect(top_pagination).to be_present
      expect(top_pagination.at_css('nav.pagy')).to be_present
      expect(frame.to_html.index(top_pagination.to_html)).to be < frame.to_html.index('<table')
    end

    it 'keeps the active filters in the pagination links' do
      get detailed_reports_path(brigade: brigade.id)

      link = parsed_doc.at_css('a[href*="page=2"]')

      expect(link['href']).to include("brigade=#{brigade.id}")
    end

    it 'keeps the position filter in the pagination links' do
      position = create(:position, department: department)
      employees.each do |employee|
        create(:department_employee, employee: employee, department: department, position: position)
      end

      get detailed_reports_path(position: position.id)

      link = parsed_doc.at_css('a[href*="page=2"]')

      expect(link['href']).to include("position=#{position.id}")
    end

    it 'keeps the active sort in the pagination links' do
      get detailed_reports_path(q: { s: 'base_salary desc' })

      link = parsed_doc.at_css('a[href*="page=2"]')
      query = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)

      expect(query.dig('q', 's')).to eq('base_salary desc')
    end

    it 'sorts all employees before paginating' do
      employees.each_with_index do |employee, index|
        create(:salary, employee: employee, department: department, amount_cents: (index + 1) * 10_000)
      end

      get detailed_reports_path(q: { s: 'base_salary desc' })

      expect(employee_id_codes).to eq(employees.last(20).reverse.map { |e| e.id_code.to_s })

      get detailed_reports_path(q: { s: 'base_salary desc' }, page: 2)

      expect(employee_id_codes).to eq(employees.first(5).reverse.map { |e| e.id_code.to_s })
    end

    it 'drops the commit param from the pagination links' do
      get detailed_reports_path(commit: I18n.t('reports.detailed.filter'))

      link = parsed_doc.at_css('a[href*="page=2"]')

      expect(link['href']).not_to include('commit')
    end

    it 'keeps all employees in the CSV export regardless of the page param' do
      get detailed_reports_path(format: :csv, page: 2)

      csv = CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ';')
      ids = csv[1..].reject { |row| row.first == I18n.t('reports.detailed.total') }.map(&:first)

      expect(ids).to match_array(employees.map { |e| e.id_code.to_s })
    end

    it 'does not pass the page param to the CSV export link' do
      get detailed_reports_path(page: 2)

      href = parsed_doc.at_css('a[href*=".csv"]')['href']

      expect(href).not_to include('page=')
    end

    it 'handles out-of-range pages without raising' do
      get detailed_reports_path(page: 999)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'CSV export without authentication' do
    before { sign_out user }

    it 'does not return the summary data' do
      get summary_reports_path(format: :csv)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Content-Disposition']).to be_nil
    end

    it 'does not return the detailed data' do
      get detailed_reports_path(format: :csv)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Content-Disposition']).to be_nil
    end
  end
end
