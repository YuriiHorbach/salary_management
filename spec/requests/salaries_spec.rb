# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Salaries', type: :request do
  let(:urls) { Rails.application.routes.url_helpers }

  let(:user) { create(:user) }
  let(:employee) { create(:employee) }
  let(:department) { create(:department) }

  let(:valid_attributes) do
    {
      amount: '50.00',
      paid_on: '2025-10-01',
      period: '2025-10',
      department_id: department.id
    }
  end

  before do
    create(:department_employee, department: department, employee: employee)
    sign_in user
  end

  describe 'authentication' do
    before { sign_out user }

    it 'redirects the index when signed out' do
      get urls.employee_salaries_path(employee)

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects the inline form when signed out' do
      get urls.new_employee_salary_path(employee, department_id: department.id)

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not create a salary when signed out' do
      expect {
        post urls.employee_salaries_path(employee),
             params: { salary: valid_attributes.except(:department_id), department_id: department.id }
      }.not_to change(Salary, :count)

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not update a salary when signed out' do
      salary = create(:salary, employee: employee, department: department,
                               amount_cents: 100_000, period: Date.new(2025, 10, 1))

      expect {
        patch urls.employee_salary_path(employee, salary), params: { salary: { amount: '999.00' } }
      }.not_to(change { salary.reload.amount_cents })

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not destroy a salary when signed out' do
      salary = create(:salary, employee: employee, department: department,
                               amount_cents: 100_000, period: Date.new(2025, 10, 1))

      expect {
        delete urls.employee_salary_path(employee, salary)
      }.not_to change(Salary, :count)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /new' do
    it 'works' do
      get urls.new_employee_salary_path(employee)
      expect(response).to have_http_status(:ok)
    end

    it 'renders an explicit submit button without auto-submit' do
      get urls.new_employee_salary_path(employee, department_id: department.id)

      page = Nokogiri::HTML(response.body)

      expect(response.body).not_to include('auto-submit')
      expect(page.at_css('input[type="submit"]')).to be_present
    end

    it 'uses the period selected on the department page' do
      get urls.new_employee_salary_path(employee, department_id: department.id, period: '2025-03')

      expect(assigns(:salary).period).to eq(Date.new(2025, 3, 1))
      period_input = Nokogiri::HTML(response.body).at_css('input[name="salary[period]"]')
      expect(period_input['value']).to eq('2025-03')
    end

    context 'when a current working month is selected' do
      let(:user) { create(:user, current_working_month: Date.new(2025, 4, 1)) }

      it 'defaults the period to the current working month' do
        get urls.new_employee_salary_path(employee, department_id: department.id)

        period_input = Nokogiri::HTML(response.body).at_css('input[name="salary[period]"]')

        expect(assigns(:salary).period).to eq(Date.new(2025, 4, 1))
        expect(period_input['value']).to eq('2025-04')
      end

      it 'still lets an explicit period param take precedence' do
        get urls.new_employee_salary_path(employee, department_id: department.id, period: '2025-03')

        expect(assigns(:salary).period).to eq(Date.new(2025, 3, 1))
      end
    end

    it 'renders a position selector with the employee positions in the department' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      get urls.new_employee_salary_path(employee, department_id: department.id)

      page = Nokogiri::HTML(response.body)
      selector = page.at_css('select[name="salary[position_id]"]')

      expect(selector).to be_present
      expect(selector.css('option').map(&:text)).to include('Без посади', 'Інженер')
      expect(page.at_css('input[name="salary[amount]"]')).to be_present
      expect(page.at_css('input[name="salary[department_id]"]')['value']).to eq(department.id.to_s)
    end

    it 'does not render a position selector when the employee has no positions in the department' do
      get urls.new_employee_salary_path(employee, department_id: department.id)

      expect(Nokogiri::HTML(response.body).at_css('select[name="salary[position_id]"]')).to be_nil
    end

    it 'prefills the position selected on the department page' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      get urls.new_employee_salary_path(employee, department_id: department.id, position_id: position.id)

      page = Nokogiri::HTML(response.body)
      selected = page.at_css('select[name="salary[position_id]"] option[selected]')

      expect(assigns(:salary).position_id).to eq(position.id)
      expect(selected['value']).to eq(position.id.to_s)
    end

    it 'defaults to the only position of the employee' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      get urls.new_employee_salary_path(employee, department_id: department.id)

      expect(assigns(:salary).position_id).to eq(position.id)
    end

    it 'leaves the position blank when the employee has several positions' do
      first_position = create(:position, department: department, position_name: 'Інженер')
      second_position = create(:position, department: department, position_name: 'Менеджер')
      create(:department_employee, employee: employee, department: department, position: first_position)
      create(:department_employee, employee: employee, department: department, position: second_position)

      get urls.new_employee_salary_path(employee, department_id: department.id)

      expect(assigns(:salary).position_id).to be_nil
    end

    it 'offers only the filtered position when a department position filter is active' do
      first_position = create(:position, department: department, position_name: 'Інженер')
      second_position = create(:position, department: department, position_name: 'Менеджер')
      create(:department_employee, employee: employee, department: department, position: first_position)
      create(:department_employee, employee: employee, department: department, position: second_position)

      get urls.new_employee_salary_path(employee, department_id: department.id,
                                                  position: first_position.id)

      options = Nokogiri::HTML(response.body)
                        .css('select[name="salary[position_id]"] option')
                        .map(&:text)

      expect(options).to include('Інженер')
      expect(options).not_to include('Менеджер', 'Без посади')
    end

    it 'ignores a position that does not belong to the employee in this department' do
      foreign_position = create(:position, department: create(:department), position_name: 'Чужа')

      get urls.new_employee_salary_path(employee, department_id: department.id,
                                                  position_id: foreign_position.id)

      expect(assigns(:salary).position_id).to be_nil
    end
  end

  describe 'GET /edit' do
    it 'renders the persisted amount as a browser-valid number' do
      salary = create(:salary, employee: employee, department: department,
                               amount_cents: 100_000, period: Date.new(2025, 10, 1))

      get urls.edit_employee_salary_path(employee, salary)

      value = Nokogiri::HTML(response.body).at_css('input[name="salary[amount]"]')['value']

      expect(value).not_to include(',')
      expect(value.to_f).to eq(1000.0)
    end

    it 'renders the employee positions in the position selector' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)
      salary = create(:salary, employee: employee, department: department,
                               amount_cents: 100_000, period: Date.new(2025, 10, 1))

      get urls.edit_employee_salary_path(employee, salary)

      options = Nokogiri::HTML(response.body)
                        .css('select[name="salary[position_id]"] option')
                        .map(&:text)

      expect(options).to include('Без посади', 'Інженер')
    end

    it 'renders employee positions when the salary has no department' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)
      salary = create(:salary, employee: employee, department: nil,
                               amount_cents: 100_000, period: Date.new(2025, 10, 1))

      get urls.edit_employee_salary_path(employee, salary)

      options = Nokogiri::HTML(response.body)
                        .css('select[name="salary[position_id]"] option')
                        .map(&:text)

      expect(options).to include('Інженер')
    end

    it 'derives the department from the selected position when updating a departmentless salary' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)
      salary = create(:salary, employee: employee, department: nil,
                               amount_cents: 100_000, period: Date.new(2025, 10, 1))

      patch urls.employee_salary_path(employee, salary),
            params: { salary: { position_id: position.id, amount: '1000.00',
                                period: '2025-10' } }

      salary.reload
      expect(salary.position).to eq(position)
      expect(salary.department).to eq(department)
    end
  end

  describe 'GET /index' do
    it 'lists every salary of the employee for the selected period across departments' do
      create(:salary, employee: employee, department: department, amount_cents: 100_000,
                      period: Date.new(2025, 10, 1))
      create(:salary, employee: employee, department: create(:department), amount_cents: 200_000,
                      period: Date.new(2025, 10, 1))
      create(:salary, employee: employee, department: department, amount_cents: 900_000,
                      period: Date.new(2025, 11, 1))

      get urls.employee_salaries_path(employee, period: '2025-10')

      expect(response).to have_http_status(:ok)
      expect(assigns(:salaries).map(&:amount_cents)).to contain_exactly(100_000, 200_000)
    end

    it 'renders the aggregated period totals from employee_period_incomes' do
      create(:salary, employee: employee, department: department, amount_cents: 100_000,
                      period: Date.new(2025, 10, 1))

      get urls.employee_salaries_path(employee, period: '2025-10')

      expect(response.body).to include('Підсумки за періодами')
      expect(response.body).to include('Всього доходу')
    end

    context 'with salaries in several positions' do
      let(:engineer) { create(:position, department: department, position_name: 'Інженер') }
      let(:manager) { create(:position, department: department, position_name: 'Менеджер') }
      let(:other_department) { create(:department, name: 'Другий підрозділ') }

      before do
        create(:department_employee, employee: employee, department: department, position: engineer)
        create(:department_employee, employee: employee, department: department, position: manager)
        create(:salary, employee: employee, department: department, position: engineer,
                        amount_cents: 100_000, period: Date.new(2025, 10, 1))
        create(:salary, employee: employee, department: department, position: manager,
                        amount_cents: 50_000, period: Date.new(2025, 10, 1))
        create(:salary, employee: employee, department: other_department,
                        amount_cents: 200_000, period: Date.new(2025, 10, 1))
      end

      it 'renders gross salary totals grouped by department and position' do
        get urls.employee_salaries_path(employee, period: '2025-10')

        expect(response.body).to include('Підсумки за посадами')
        expect(response.body).to include('Інженер', '1000,00', 'Менеджер', '500,00',
                                         'Другий підрозділ', '2000,00')
        expect(assigns(:salary_totals_by_position)).to include(
          [department.id, engineer.id] => 100_000,
          [department.id, manager.id] => 50_000,
          [other_department.id, nil] => 200_000
        )
      end
    end

    it 'sorts position totals by department name and position name' do
      late_department = create(:department, name: 'Ялинка')
      early_department = create(:department, name: 'Альфа')
      create(:salary, employee: employee, department: late_department, amount_cents: 100_000,
                      period: Date.new(2025, 10, 1))
      create(:salary, employee: employee, department: early_department, amount_cents: 200_000,
                      period: Date.new(2025, 10, 1))

      get urls.employee_salaries_path(employee, period: '2025-10')

      rows = Nokogiri::HTML(response.body)
                     .css('#salary_totals_by_position tbody tr')
      department_names = rows.map { |row| row.css('td').first.text.strip }

      expect(department_names).to eq(%w[Альфа Ялинка])
    end

    it 'sorts position totals within one department by position name' do
      alpha = create(:position, department: department, position_name: 'Alpha')
      beta = create(:position, department: department, position_name: 'Beta')
      create(:department_employee, employee: employee, department: department, position: alpha)
      create(:department_employee, employee: employee, department: department, position: beta)
      create(:salary, employee: employee, department: department, position: beta, amount_cents: 200_000,
                      period: Date.new(2025, 10, 1))
      create(:salary, employee: employee, department: department, position: alpha, amount_cents: 100_000,
                      period: Date.new(2025, 10, 1))

      get urls.employee_salaries_path(employee, period: '2025-10')

      rows = Nokogiri::HTML(response.body)
                     .css('#salary_totals_by_position tbody tr')
      position_names = rows.map { |row| row.css('td')[1].text.strip }

      expect(position_names).to eq(%w[Alpha Beta])
    end

    it 'limits position totals to the selected period' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)
      create(:salary, employee: employee, department: department, position: position,
                      amount_cents: 100_000, period: Date.new(2025, 10, 1))
      create(:salary, employee: employee, department: department, position: position,
                      amount_cents: 900_000, period: Date.new(2025, 11, 1))

      get urls.employee_salaries_path(employee, period: '2025-10')

      expect(assigns(:salary_totals_by_position)).to eq(
        [department.id, position.id] => 100_000
      )
    end

    it 'formats amounts without thousands separators and with a comma decimal' do
      create(:salary, employee: employee, department: department, amount_cents: 1_832_420,
                      period: Date.new(2025, 10, 1))

      get urls.employee_salaries_path(employee, period: '2025-10')

      expect(response.body).to include('18324,20')
      expect(response.body).not_to include('18,324.20', '₴18324,20', '18324,20 ₴', '$18324,20')
    end

    it 'renders links to every department the employee belongs to' do
      second_department = create(:department, name: 'Другий підрозділ')
      unrelated_department = create(:department, name: 'Не свій підрозділ')
      create(:department_employee, employee: employee, department: second_department)

      get urls.employee_salaries_path(employee, period: '2025-10')

      page = Nokogiri::HTML(response.body)
      link_texts = page.css('a').map { |link| link.text.strip }
      link_paths = page.css('a').map { |link| link['href'] }

      expect(link_texts).to include(department.name, second_department.name)
      expect(link_paths).to include(
        urls.department_path(department, period: '2025-10'),
        urls.department_path(second_department, period: '2025-10')
      )
      expect(page.text).not_to include(unrelated_department.name)
    end

    it 'shows a link back to the employee when there are no departments' do
      employee.department_employees.destroy_all

      get urls.employee_salaries_path(employee)

      page = Nokogiri::HTML(response.body)

      expect(page.at_css("a[href='#{urls.employee_path(employee)}']").text.strip).to eq('Back to employee')
    end
  end

  describe 'PATCH /update' do
    let(:position) { create(:position, department: department, position_name: 'Інженер') }
    let!(:salary) do
      create(:salary, employee: employee, department: department,
                      amount_cents: 100_000, period: Date.new(2025, 10, 1))
    end

    before do
      create(:department_employee, employee: employee, department: department, position: position)
    end

    it 'assigns the selected position without changing the amount' do
      patch urls.employee_salary_path(employee, salary),
            params: { salary: { position_id: position.id, department_id: department.id,
                                period: '2025-10' } }

      salary.reload
      expect(salary.position).to eq(position)
      expect(salary.amount_cents).to eq(100_000)
    end

    it 'redirects back to the salary list for the salary period' do
      patch urls.employee_salary_path(employee, salary),
            params: { salary: { amount: '1000.00', position_id: position.id,
                                department_id: department.id, period: '2025-10' } }

      expect(response).to redirect_to(
        urls.employee_salaries_path(employee, period: '2025-10')
      )
    end

    it 'ignores a forged employee_id in the salary params' do
      other_employee = create(:employee)
      create(:department_employee, employee: other_employee, department: department, position: position)

      patch urls.employee_salary_path(employee, salary),
            params: { salary: { employee_id: other_employee.id, amount: '1000.00',
                                position_id: position.id, department_id: department.id,
                                period: '2025-10' } }

      expect(salary.reload.employee).to eq(employee)
    end

    it 'refreshes position totals in the turbo_stream response' do
      patch urls.employee_salary_path(employee, salary),
            params: { salary: { amount: '2500.00', department_id: department.id, period: '2025-10' } },
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      totals = turbo_stream_content('salary_totals_by_position_section')

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(totals.text).to include('2500,00')
    end

    it 'renders turbo_stream validation errors for an invalid update' do
      create(:salary, employee: employee, department: department, amount_cents: 200_000,
                      period: Date.new(2025, 11, 1))

      patch urls.employee_salary_path(employee, salary),
            params: { salary: { amount: '1234.56', department_id: department.id,
                                period: '2025-11' } },
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')

      page = Nokogiri::HTML(response.body)
      stream = page.at_css("turbo-stream[action=\"replace\"][target=\"salary_#{salary.id}\"]")
      form = Nokogiri::HTML.fragment(stream.at_css('template').inner_html)

      expect(form.at_css('input[name="salary[amount]"]')['value'].to_f).to eq(1234.56)
      expect(form.text).to include('уже додано')
    end
  end

  describe 'DELETE /destroy' do
    let(:engineer) { create(:position, department: department, position_name: 'Інженер') }
    let(:manager) { create(:position, department: department, position_name: 'Менеджер') }
    let(:engineer_salary) do
      create(:salary, employee: employee, department: department, position: engineer,
                      amount_cents: 100_000, period: Date.new(2025, 10, 1))
    end

    before do
      create(:department_employee, employee: employee, department: department, position: engineer)
      create(:department_employee, employee: employee, department: department, position: manager)
      engineer_salary
      create(:salary, employee: employee, department: department, position: manager,
                      amount_cents: 200_000, period: Date.new(2025, 10, 1))
    end

    it 'removes the salary and refreshes position totals in the turbo_stream response' do
      expect {
        delete urls.employee_salary_path(employee, engineer_salary),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      }.to change(Salary, :count).by(-1)

      totals = turbo_stream_content('salary_totals_by_position_section')

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(totals.text).to include('2000,00')
      expect(totals.text).not_to include('1000,00')
    end
  end

  describe 'POST /create' do
    it 'creates a salary' do
      expect {
        post urls.employee_salaries_path(employee),
             params: { salary: valid_attributes.except(:department_id), department_id: department.id }
      }.to change(employee.salaries, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(employee.salaries.last.amount_cents).to eq(5000)
      expect(employee.salaries.last.department_id).to eq(department.id)
      expect(employee.salaries.last.position_id).to be_nil
      expect(employee.salaries.last.period).to eq(Date.new(2025, 10, 1))
      expect(response).to redirect_to(department_path(department, period: '2025-10'))
    end

    it 'creates the salary without a position even when the employee has one' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id), department_id: department.id }

      expect(employee.salaries.last.position_id).to be_nil
    end

    it 'ignores a top-level position_id outside strong params' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id), department_id: department.id,
                     position_id: position.id }

      expect(employee.salaries.last.position_id).to be_nil
    end

    it 'responds with turbo_stream format' do
      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id), department_id: department.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('data-turbo-frame="_top"')
      expect(response.body).to include("target=\"salary_cell_employee_#{employee.id}\"")
    end

    it 'does not create a salary with empty amount' do
      expect {
        post urls.employee_salaries_path(employee),
             params: { salary: { amount: '', paid_on: '2025-10-01', department_id: department.id } }
      }.not_to change(employee.salaries, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not create a second salary for the same employee, period and department without a position' do
      create(:salary, employee: employee, department: department, period: Date.new(2025, 10, 1))

      expect {
        post urls.employee_salaries_path(employee),
             params: { salary: valid_attributes.except(:department_id), department_id: department.id }
      }.not_to change(employee.salaries, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'creates another salary for the same employee and period in a different department' do
      create(:salary, employee: employee, department: create(:department), period: Date.new(2025, 10, 1))

      expect {
        post urls.employee_salaries_path(employee),
             params: { salary: valid_attributes.except(:department_id), department_id: department.id }
      }.to change(employee.salaries, :count).by(1)

      expect(response).to have_http_status(:found)
    end

    it 'creates a salary for a position assigned to the employee' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      expect {
        post urls.employee_salaries_path(employee),
             params: { salary: valid_attributes.except(:department_id).merge(position_id: position.id),
                       department_id: department.id }
      }.to change(employee.salaries, :count).by(1)

      expect(employee.salaries.last.position).to eq(position)
      expect(response).to have_http_status(:found)
    end

    it 'redirects back to the department keeping an explicit position filter' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id).merge(position_id: position.id),
                     department_id: department.id, position: position.id }

      expect(response).to redirect_to(
        urls.department_path(department, period: '2025-10', position: position.id)
      )
    end

    it 'does not filter the department by the new salary position when no filter was active' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id).merge(position_id: position.id),
                     department_id: department.id }

      expect(response).to redirect_to(
        urls.department_path(department, period: '2025-10')
      )
    end

    it 'drops the position filter when a positionless salary is created under a filter' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id),
                     department_id: department.id, position: position.id }

      expect(response).to redirect_to(
        urls.department_path(department, period: '2025-10')
      )
      expect(employee.salaries.last.position_id).to be_nil
    end

    it 'renders an unfiltered cell without the stale position filter after a positionless inline create' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id),
                     department_id: department.id, position: position.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      cell = turbo_stream_content("salary_cell_employee_#{employee.id}")
      total = turbo_stream_content('department_total', action: 'update')
      add_link = cell.at_css("a[href*='position_id=#{position.id}']")

      expect(cell.text).to include('Без посади', '50,00', 'Інженер')
      expect(add_link['href']).not_to match(/[?&]position=/)
      expect(total.text).to include('50,00')
    end

    it 'updates the department total and salary cell after an inline create' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)
      create(:salary, employee: employee, department: department, amount_cents: 100_000,
                      period: Date.new(2025, 10, 1))

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id).merge(position_id: position.id),
                     department_id: department.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      page = Nokogiri::HTML(response.body)
      total_stream = page.at_css('turbo-stream[action="update"][target="department_total"]')
      cell_stream = page.at_css("turbo-stream[action=\"replace\"][target=\"salary_cell_employee_#{employee.id}\"]")

      expect(total_stream.text).to include('1050,00')
      expect(cell_stream.text).to include('1000,00', '50,00')
    end

    it 'keeps the typed amount and position when the inline create fails' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)
      create(:salary, employee: employee, department: department, position: position,
                      amount_cents: 100_000, period: Date.new(2025, 10, 1))

      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id).merge(position_id: position.id,
                                                                           amount: '1234.56'),
                     department_id: department.id }

      expect(response).to have_http_status(:unprocessable_entity)
      page = Nokogiri::HTML(response.body)
      amount_input = page.at_css('input[name="salary[amount]"]')
      selected = page.at_css('select[name="salary[position_id]"] option[selected]')

      expect(amount_input['value'].to_f).to eq(1234.56)
      expect(selected['value']).to eq(position.id.to_s)
    end

    context 'when a duplicate position salary exists' do
      let(:position) { create(:position, department: department, position_name: 'Інженер') }

      before do
        create(:department_employee, employee: employee, department: department, position: position)
        create(:salary, employee: employee, department: department, position: position,
                        amount_cents: 100_000, period: Date.new(2025, 10, 1))
      end

      it 'renders turbo_stream validation errors for an inline create' do
        post_inline_salary(position, amount: '1234.56')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')

        form = turbo_stream_content("salary_cell_employee_#{employee.id}")
        expect(form.at_css('input[name="salary[amount]"]')['value'].to_f).to eq(1234.56)
        expect(form.at_css('select[name="salary[position_id]"] option[selected]')['value'])
          .to eq(position.id.to_s)
        expect(form.text).to include('уже додано')
      end
    end
  end

  def post_inline_salary(position, amount:)
    post urls.employee_salaries_path(employee),
         params: { salary: valid_attributes.except(:department_id).merge(position_id: position.id,
                                                                         amount: amount),
                   department_id: department.id },
         headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
  end

  def turbo_stream_content(target, action: 'replace')
    page = Nokogiri::HTML(response.body)
    stream = page.at_css("turbo-stream[action=\"#{action}\"][target=\"#{target}\"]")
    Nokogiri::HTML.fragment(stream.at_css('template').inner_html)
  end
end
