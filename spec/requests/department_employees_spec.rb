# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DepartmentEmployees', type: :request do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let!(:employee1) { create(:employee) }
  let!(:employee2) { create(:employee) }
  let(:department) { create(:department) }

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
