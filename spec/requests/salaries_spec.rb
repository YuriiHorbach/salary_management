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

  describe 'GET /new' do
    it 'works' do
      get urls.new_employee_salary_path(employee)
      expect(response).to have_http_status(:ok)
    end

    it 'renders form with auto-submit Stimulus controller' do
      get urls.new_employee_salary_path(employee, department_id: department.id)
      expect(response.body).to include('data-controller="auto-submit"')
      expect(response.body).to include('blur-&gt;auto-submit#submit')
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

    it 'renders the positions assigned to the employee in the selected department' do
      position = create(:position, department: department, position_name: 'Інженер')
      create(:department_employee, employee: employee, department: department, position: position)

      get urls.new_employee_salary_path(employee, department_id: department.id)

      selector = Nokogiri::HTML(response.body).at_css('select[name="salary[position_id]"]')

      expect(selector).to be_present
      expect(selector.text).to include('Інженер', 'Без посади')
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
      expect(employee.salaries.last.period).to eq(Date.new(2025, 10, 1))
      expect(response).to redirect_to(department_path(department, period: '2025-10'))
    end

    it 'responds with turbo_stream format' do
      post urls.employee_salaries_path(employee),
           params: { salary: valid_attributes.except(:department_id), department_id: department.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('data-turbo-frame="_top"')
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
  end
end
