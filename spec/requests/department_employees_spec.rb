# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DepartmentEmployees', type: :request do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let!(:employee1) { create(:employee) }
  let!(:employee2) { create(:employee) }
  let(:department) { create(:department) }
  let!(:position) { create(:position, department: department) }
  let!(:other_position) { create(:position, department: department) }

  describe 'POST /department_employees' do
    context 'when authorized' do
      before { sign_in user }

      it 'successfully adds employees to the department' do
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id, employee2.id]
        }
        expect(response).to redirect_to(department_path(department))
      end

      it 'adds every selected employee to the department at once' do
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id, employee2.id]
        }

        expect(department.employees.reload).to contain_exactly(employee1, employee2)
      end

      it 'adds the selected position to the employees' do
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id],
          position_id: position.id
        }

        assignment = department.department_employees.find_by(employee_id: employee1.id)

        expect(assignment.position).to eq(position)
      end

      it 'adds another position to an employee who is already in the department' do
        create(:department_employee, employee: employee1, department: department, position: position)

        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id],
          position_id: other_position.id
        }

        assignments = department.department_employees.where(employee_id: employee1.id)

        expect(assignments.count).to eq(2)
        expect(assignments.map(&:position)).to contain_exactly(position, other_position)
      end

      it 'does not add the same position to the same employee twice' do
        create(:department_employee, employee: employee1, department: department, position: position)

        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id],
          position_id: position.id
        }

        assignments = department.department_employees.where(employee_id: employee1.id, position: position)

        expect(assignments.count).to eq(1)
      end

      it 'renders a position selector with the department positions' do
        get new_department_employee_path(department_id: department.id)

        selector = Nokogiri::HTML(response.body).at_css('select[name="position_id"]')

        expect(selector).to be_present
        expect(selector.text).to include(position.position_name, other_position.position_name)
      end

      it 'ignores employees that are already in the department' do
        department.employees << employee1

        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id, employee2.id]
        }

        expect(department.employees.reload).to contain_exactly(employee1, employee2)
      end

      it 'renders a checkbox for every employee on the add page' do
        get new_department_employee_path(department_id: department.id)

        checkboxes = Nokogiri::HTML(response.body).css('input[name="employee_ids[]"]')

        expect(response).to have_http_status(:ok)
        expect(checkboxes.map { |checkbox| checkbox['value'] }).to contain_exactly(
          employee1.id.to_s, employee2.id.to_s
        )
      end

      it 'filters employees by a partial id code' do
        matching_employee = create(:employee, id_code: '7777777701')
        non_matching_employee = create(:employee, id_code: '6666666602')

        get new_department_employee_path(department_id: department.id, q: { id_code_cont: '77777' })

        employee_ids = Nokogiri::HTML(response.body)
                               .css('input[name="employee_ids[]"]')
                               .map { |checkbox| checkbox['value'] }

        expect(employee_ids).to include(matching_employee.id.to_s)
        expect(employee_ids).not_to include(non_matching_employee.id.to_s)
      end

      it 'finds passport-style id codes typed in lowercase' do
        passport_employee = create(:employee, id_code: 'ББ654321')

        get new_department_employee_path(department_id: department.id, q: { id_code_cont: 'бб65' })

        employee_ids = Nokogiri::HTML(response.body)
                               .css('input[name="employee_ids[]"]')
                               .map { |checkbox| checkbox['value'] }

        expect(employee_ids).to include(passport_employee.id.to_s)
      end

      it 'keeps sorting when filtering by a partial id code' do
        create(:employee, id_code: '5555555501')
        create(:employee, id_code: '5555555502')

        get new_department_employee_path(department_id: department.id,
                                         q: { id_code_cont: '55555', s: 'id_code desc' })

        employee_codes = Nokogiri::HTML(response.body)
                                 .css('tbody tr td:first-child')
                                 .map { |cell| cell.text.strip }

        expect(employee_codes).to eq(%w[5555555502 5555555501])
      end

      it 'renders controls for selecting and adding several employees at once' do
        get new_department_employee_path(department_id: department.id)

        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css('form[data-controller="bulk-select"]')).to be_present
        expect(doc.at_css('input[data-bulk-select-target="toggleAll"]')).to be_present
        expect(doc.at_css('[data-bulk-select-target="count"]')).to be_present
        expect(doc.css('input[data-bulk-select-target="checkbox"]').size).to eq(2)
      end

      it 'does not add anyone when no employees are selected' do
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: []
        }

        expect(department.employees.reload).to be_empty
        expect(response).to redirect_to(department_path(department))

        follow_redirect!
        expect(response.body).to include('No employees selected.')
      end

      it 'ignores ids that do not belong to any employee' do
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id, 0, 'junk']
        }

        expect(department.employees.reload).to contain_exactly(employee1)
      end

      it 'does not create duplicate join rows for the same employee' do
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id, employee1.id]
        }

        expect(department.department_employees.where(employee_id: employee1.id).count).to eq(1)
      end

      def assign_employees(count, assigned_position)
        create_list(:employee, count).each do |employee|
          create(:department_employee, employee: employee, department: department, position: assigned_position)
        end
      end

      def post_assignment(employees, assigned_position)
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: employees.map(&:id),
          position_id: assigned_position.id
        }
      end

      it 'executes the same number of queries regardless of how many employees are already assigned' do
        already_assigned = assign_employees(2, position)

        # Warm up one-time session and authentication lookups before measuring.
        get new_department_employee_path(department_id: department.id)
        first_request_queries = count_sql_queries { post_assignment(already_assigned, position) }

        extra_assigned = assign_employees(3, position)
        second_request_queries = count_sql_queries do
          post_assignment(already_assigned + extra_assigned, position)
        end

        expect(second_request_queries).to eq(first_request_queries)
      end

      it 'shows the whole employee list by default' do
        create_list(:employee, 16)

        get new_department_employee_path(department_id: department.id)

        expect(assigns(:pagy)).to be_nil
        expect(assigns(:employees).size).to eq(18)
      end

      it 'paginates the employee list when requested' do
        create_list(:employee, 16)

        get new_department_employee_path(department_id: department.id, paginate: '1')

        expect(assigns(:pagy).last).to eq(2)
        expect(assigns(:employees).size).to eq(DepartmentEmployeesController::EMPLOYEES_PER_PAGE)
      end

      it 'renders a toggle that preserves the current search' do
        get new_department_employee_path(department_id: department.id, q: { id_code_cont: '777' })

        toggle = Nokogiri::HTML(response.body).css('a').find do |link|
          link.text.strip == I18n.t('department_employees.new.paginate')
        end

        expect(toggle['href']).to include('paginate=1')
        expect(toggle['href']).to include('id_code_cont')
      end

      it 'shows the full-list toggle when pagination is enabled' do
        get new_department_employee_path(department_id: department.id, paginate: '1')

        expect(response.body).to include(I18n.t('department_employees.new.show_all'))
      end

      it 'caps the full list and asks the user to narrow the search' do
        stub_const('DepartmentEmployeesController::MAX_UNPAGINATED_EMPLOYEES', 2)
        create_list(:employee, 2)

        get new_department_employee_path(department_id: department.id)

        expect(assigns(:employees).size).to eq(2)
        expect(assigns(:employees_truncated)).to be(true)
        expect(response.body).to include(I18n.t('department_employees.new.limit_notice', count: 2))
      end

      it 'removes employee from department' do
        department.employees << employee1
        delete remove_department_employee_path(department, employee1)

        expect(department.employees.exists?(employee1.id)).to be_falsy
        expect(response).to redirect_to(department_path(department))
      end
    end

    context 'when unauthorized' do
      it 'redirects to the login page' do
        post department_employees_path, params: {
          department_id: department.id,
          employee_ids: [employee1.id]
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
