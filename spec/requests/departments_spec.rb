# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Departments', type: :request do
  let(:user) { create :user }

  def rendered_last_names
    Nokogiri::HTML(response.body)
            .css('tbody tr')
            .filter_map { |row| row.css('td')[1]&.text&.strip }
  end

  def employee_row(last_name)
    Nokogiri::HTML(response.body).css('tbody tr').find { |row| row.text.include?(last_name) }
  end

  describe 'GET /index' do
    context 'when user is authorized' do
      it 'shows a departments list' do
        sign_in(user)
        get departments_path

        expect(response).to be_successful
      end
    end

    context 'when admin unauthorized' do
      it 'does not see users list' do
        get departments_path
        expect(response).to redirect_to(user_session_path)
      end
    end
  end

  describe 'GET /show' do
    context 'when authorized' do
      let(:department) { create(:department) }
      let!(:manager_position) { create(:position, department: department, position_name: 'Manager') }
      let!(:engineer_position) { create(:position, department: department, position_name: 'Engineer') }
      let!(:alpha) do
        create(:employee, id_code: '1000000001', last_name: 'Alpha', first_name: 'Anna', patronic_name: 'Andriivna')
      end
      let!(:zeta) do
        create(:employee, id_code: '9000000002', last_name: 'Zeta', first_name: 'Zoe', patronic_name: 'Zakharivna')
      end

      before do
        create(:department_employee, employee: alpha, department: department, position: manager_position)
        create(:department_employee, employee: zeta, department: department, position: engineer_position)
        sign_in(user)
      end

      it 'shows a department page' do
        get department_path(department.id)

        expect(response).to be_successful
      end

      it 'sorts employees by last name ascending' do
        get department_path(department, q: { s: 'last_name asc' })

        expect(response).to be_successful
        expect(rendered_last_names).to eq(%w[Alpha Zeta])
      end

      it 'sorts employees by last name descending' do
        get department_path(department, q: { s: 'last_name desc' })

        expect(rendered_last_names).to eq(%w[Zeta Alpha])
      end

      it 'sorts employees by id code' do
        get department_path(department, q: { s: 'id_code desc' })

        expect(rendered_last_names).to eq(%w[Zeta Alpha])
      end

      it 'only renders employees that belong to the department' do
        create(:employee, id_code: '5000000003', last_name: 'Outsider', first_name: 'Olha', patronic_name: 'Olehivna')

        get department_path(department)

        expect(rendered_last_names).to contain_exactly('Alpha', 'Zeta')
        expect(response.body).not_to include('Outsider')
      end

      it 'filters employees by position' do
        get department_path(department, position: engineer_position.id)

        expect(rendered_last_names).to contain_exactly('Zeta')
      end

      it 'renders a position filter with the department positions' do
        get department_path(department)

        selector = Nokogiri::HTML(response.body).at_css('select[name="position"]')

        expect(selector).to be_present
        expect(selector.text).to include('Manager', 'Engineer')
      end

      it 'keeps the selected position in the filter' do
        get department_path(department, position: engineer_position.id)

        selected = Nokogiri::HTML(response.body).at_css('select[name="position"] option[selected]')

        expect(selected['value']).to eq(engineer_position.id.to_s)
      end

      it 'keeps the position filter in the sort links' do
        get department_path(department, position: engineer_position.id)

        link = Nokogiri::HTML(response.body).at_css('thead th a')

        expect(link['href']).to include("position=#{engineer_position.id}")
      end

      it 'does not duplicate an employee who has several positions' do
        create(:department_employee, employee: alpha, department: department, position: engineer_position)

        get department_path(department)

        expect(rendered_last_names.count('Alpha')).to eq(1)
      end

      it 'lets the browser size the columns dynamically' do
        get department_path(department)

        table = Nokogiri::HTML(response.body).at_css('table')
        fixed_width_headers = table.css('thead th[class*="w-["]')

        expect(table['class']).to include('table-auto')
        expect(table['class']).not_to include('table-fixed')
        expect(fixed_width_headers).to be_empty
      end

      it 'renders a salary history column with a link for every employee' do
        get department_path(department)

        rows = Nokogiri::HTML(response.body).css('tbody tr')

        [alpha, zeta].each do |employee|
          row = rows.find { |r| r.text.include?(employee.last_name) }
          expected_path = employee_salaries_path(employee, department_id: department.id,
                                                           period: Date.current.strftime('%Y-%m'))
          link = row.at_css("a[href='#{expected_path}']")

          expect(link).to be_present
          expect(link.text.strip).to eq('Salary')
        end
      end

      it 'renders the salary history column header' do
        get department_path(department)

        headers = Nokogiri::HTML(response.body).css('thead th').map { |header| header.text.strip }

        expect(headers).to include('View salary')
      end

      it 'renders sortable headers for the employee columns' do
        get department_path(department)

        headers = Nokogiri::HTML(response.body).css('thead th a')

        expect(headers.map(&:text)).to include('ID', 'Last name', 'First name', 'Patronic name')
        expect(headers.map { |link| link['href'] }).to all(include('q%5Bs%5D'))
      end

      it 'defaults the selected period to the current month' do
        get department_path(department)

        period_input = Nokogiri::HTML(response.body).at_css('input[name="period"]')

        expect(period_input['value']).to eq(Date.current.strftime('%Y-%m'))
      end

      it 'defaults the selected period to the current working month' do
        user.update!(current_working_month: Date.new(2025, 4, 1))
        get department_path(department)

        period_input = Nokogiri::HTML(response.body).at_css('input[name="period"]')

        expect(assigns(:period)).to eq(Date.new(2025, 4, 1))
        expect(period_input['value']).to eq('2025-04')
      end

      it 'keeps the selected period in the period selector' do
        get department_path(department, period: '2025-03')

        period_input = Nokogiri::HTML(response.body).at_css('input[name="period"]')

        expect(period_input['value']).to eq('2025-03')
      end

      it 'shows the selected period in the salary column header' do
        get department_path(department, period: '2025-03')

        headers = Nokogiri::HTML(response.body).css('thead th').map { |header| header.text.strip }

        expect(headers).to include('Зарплата за 03-2025')
      end

      it 'shows the salary for the selected period instead of the last salary' do
        create(:salary, employee: alpha, department: department, amount_cents: 100_000,
                        period: Date.new(2025, 3, 1))
        create(:salary, employee: alpha, department: department, amount_cents: 900_000,
                        period: Date.new(2025, 4, 1))

        get department_path(department, period: '2025-03')

        row = employee_row('Alpha')
        expect(row.text).to include('1000,00')
        expect(row.text).not_to include('9000,00')
      end

      it 'sums all salaries in this department for an employee with several positions' do
        create(:department_employee, employee: alpha, department: department, position: engineer_position)
        create(:salary, employee: alpha, department: department, position: manager_position,
                        amount_cents: 100_000, period: Date.new(2025, 3, 1))
        create(:salary, employee: alpha, department: department, position: engineer_position,
                        amount_cents: 50_000, period: Date.new(2025, 3, 1))

        get department_path(department, period: '2025-03')

        expect(employee_row('Alpha').text).to include('1500,00')
      end

      it 'shows only the salary of the filtered position in the employee row' do
        create(:department_employee, employee: alpha, department: department, position: engineer_position)
        create(:salary, employee: alpha, department: department, position: manager_position,
                        amount_cents: 100_000, period: Date.new(2025, 3, 1))
        create(:salary, employee: alpha, department: department, position: engineer_position,
                        amount_cents: 50_000, period: Date.new(2025, 3, 1))

        get department_path(department, period: '2025-03', position: engineer_position.id)

        row = employee_row('Alpha')
        expect(row.text).to include('500,00')
        expect(row.text).not_to include('1500,00')
      end

      it 'shows the department total for the filtered position only' do
        create(:department_employee, employee: alpha, department: department, position: engineer_position)
        create(:salary, employee: alpha, department: department, position: manager_position,
                        amount_cents: 100_000, period: Date.new(2025, 3, 1))
        create(:salary, employee: alpha, department: department, position: engineer_position,
                        amount_cents: 50_000, period: Date.new(2025, 3, 1))

        get department_path(department, period: '2025-03', position: engineer_position.id)

        expect(assigns(:department_total)).to eq(500.0)
        expect(response.body).to include('500,00')
        expect(response.body).not_to include('1500,00')
      end

      it 'excludes salaries without a position when a position is selected' do
        create(:department_employee, employee: alpha, department: department, position: engineer_position)
        create(:salary, employee: alpha, department: department, amount_cents: 100_000,
                        period: Date.new(2025, 3, 1))
        create(:salary, employee: alpha, department: department, position: engineer_position,
                        amount_cents: 50_000, period: Date.new(2025, 3, 1))

        get department_path(department, period: '2025-03', position: engineer_position.id)

        expect(assigns(:period_salaries)[alpha.id]).to eq(50_000)
        expect(assigns(:department_total)).to eq(500.0)
      end

      it 'renders no salary for a position that has no matching salary in the period' do
        create(:salary, employee: alpha, department: department, amount_cents: 100_000,
                        period: Date.new(2025, 3, 1))

        get department_path(department, period: '2025-03', position: engineer_position.id)

        expect(assigns(:period_salaries)).to be_empty
        expect(assigns(:department_total)).to eq(0.0)
        expect(employee_row('Zeta').text).to include('+ Додати')
      end

      it 'shows only the filtered position in the employee positions column' do
        create(:department_employee, employee: alpha, department: department, position: engineer_position)

        get department_path(department, position: engineer_position.id)

        row = employee_row('Alpha')
        expect(row.text).to include('Engineer')
        expect(row.text).not_to include('Manager')
      end

      it 'passes the filtered position to the add salary link' do
        get department_path(department, period: '2025-03', position: engineer_position.id)

        row = employee_row('Zeta')
        link = row.at_css("a[href*='/employees/#{zeta.id}/salaries/new']")

        expect(link).to be_present
        query = Rack::Utils.parse_query(URI.parse(link['href']).query)
        expect(query['position_id']).to eq(engineer_position.id.to_s)
      end

      it 'opens the salary history outside the department turbo frame' do
        create(:salary, employee: alpha, department: department, amount_cents: 100_000,
                        period: Date.new(2025, 3, 1))

        get department_path(department, period: '2025-03')

        link = employee_row('Alpha').at_css("a[href='#{employee_salaries_path(alpha, period: '2025-03')}']")

        expect(link['data-turbo-frame']).to eq('_top')
      end

      it 'does not render an add link for an employee that already has a salary in the period' do
        create(:salary, employee: alpha, department: department, amount_cents: 100_000,
                        period: Date.new(2025, 3, 1))

        get department_path(department, period: '2025-03')

        row = employee_row('Alpha')
        expect(row.at_css("a[href*='/employees/#{alpha.id}/salaries/new']")).to be_nil
      end

      it 'passes the selected period to the add salary link' do
        get department_path(department, period: '2025-03')

        row = employee_row('Zeta')
        link = row.at_css("a[href*='/employees/#{zeta.id}/salaries/new']")

        expect(link).to be_present
        query = Rack::Utils.parse_query(URI.parse(link['href']).query)
        expect(query['period']).to eq('2025-03')
        expect(query['department_id']).to eq(department.id.to_s)
      end

      it 'shows the department total for the selected period only' do
        create(:salary, employee: alpha, department: department, amount_cents: 100_000,
                        period: Date.new(2025, 3, 1))
        create(:salary, employee: zeta, department: department, amount_cents: 50_000,
                        period: Date.new(2025, 3, 1))
        create(:salary, employee: alpha, department: department, amount_cents: 900_000,
                        period: Date.new(2025, 4, 1))

        get department_path(department, period: '2025-03')

        expect(response.body).to include('1500,00')
        expect(response.body).not_to include('10500,00')
      end
    end

    context 'when unauthorized' do
      it 'redirect to the root_path' do
        department = create(:department)
        get department_path(department.id)

        expect(response).to redirect_to(user_session_path)
      end
    end
  end
end
