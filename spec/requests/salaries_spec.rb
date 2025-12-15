require 'rails_helper'
RSpec.describe 'Salaries', type: :request do
  let(:user) { create(:user) }
  let(:employee) { create(:employee) }
  let(:department) { create(:department, name: 'AdmitDep') }
  let(:other_department) { create(:department, name: 'TestDep') }

  let(:valid_attributes) do
    {
      amount: 5000,
      paid_on: '2025-10-01',
      department_id: department.id
    }
  end

  let(:known_password) { 'testing123' }
  let(:user) { create(:user, password: known_password, password_confirmation: known_password) }

  before do
    post user_session_path, params: {
      user: {
        email: user.email,
        password: known_password
      }
    }
  end

  describe 'GET /new' do
    it 'assigns a new salary initialized with department_id if provided' do
      get new_employee_salary_path(employee_id: employee.id, department_id: other_department.id)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      let(:create_request) do
        post employee_salaries_path(employee_id: employee.id), params: { salary: valid_attributes }
      end

      it 'creates a new Salary record' do
        expect { create_request }.to change(Salary, :count).by(1)
      end

      it 'saves the correct department_id and redirects' do
        create_request

        created_salary = Salary.last
        expect(created_salary.department_id).to eq(department.id)

        expect(response).to redirect_to(employee_salaries_path(employee))
        expect(response).to have_http_status(:found)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) { valid_attributes.merge(amount: nil) }

      it 'does not create a new Salary record' do
        expect do
          post employee_salaries_path(employee_id: employee.id), params: { salary: invalid_attributes }
        end.not_to change(Salary, :count)
      end

      it 'returns unprocessable entity status' do
        post employee_salaries_path(employee_id: employee.id), params: { salary: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
