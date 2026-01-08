# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DepartmentEmployees', type: :request do
  let(:user) { create(:user) }
  let(:employee1) { create(:employee) }
  let(:employee2) { create(:employee) }
  let(:department) { create(:department) }

  describe 'POST /department_employees' do
    context 'when authorized' do
      before do
        sign_in user, scope: :user
      end

      it 'successfully adds employees to the department' do
        expect do
          post department_employees_path, params: {
            department_id: department.id,
            employee_ids: [employee1.id, employee2.id]
          }, as: :turbo_stream
        end.to change { department.employees.count }.by(2)

        expect(response).to redirect_to(department_path(department.id))
      end

      it 'does not add employees if no employee_ids are provided' do
        post department_employees_path, params: { department_id: department.id }

        expect(department.employees.count).to eq(0)
        expect(response).to redirect_to(department_path(department))
      end
    end

    context 'when unauthorized' do
      it 'redirects to the login page' do
        post department_employees_path, params: { department_id: department.id, employee_ids: [employee1.id] }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
