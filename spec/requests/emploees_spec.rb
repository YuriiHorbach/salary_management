# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Employees', type: :request do
  let(:user) { create :user }

  describe 'GET /index' do
    context 'when user is authorized' do
      it 'shows a link to employee list' do
        user = create(:user)
        sign_in(user)

        get employees_path

        expect(response).to be_successful
      end
    end

    context 'when admin unauthorized' do
      it 'does not see users list' do
        get employees_path

        expect(response).to redirect_to(user_session_path)
      end
    end
  end

  describe 'GET /show' do
    context 'when authorized' do
      it 'shows a employee page' do
        user = create :user
        employee = create(:employee)
        sign_in(user)
        get employee_path(employee.id)

        expect(response).to be_successful
      end
    end

    context 'when unauthorized' do
      it 'redirect to the root_path' do
        create :user
        employee = create(:employee)
        get employee_path(employee.id)

        expect(response).to redirect_to(user_session_path)
      end
    end
  end

  describe 'Employee /create' do
    context 'when authorized' do
      it 'renders a successful response' do
        user = create :user
        sign_in(user)

        expect do
          post employees_path, params: { employee: attributes_for(:employee,
                                                                  id_code: 1_111_111_111,
                                                                  first_name: 'John',
                                                                  patronic_name: 'Testovich',
                                                                  last_name: 'Brown') }
        end.to change(Employee, :count).by(1)

        expect(response).to redirect_to(employees_path)
      end
    end

    context 'when unauthorized' do
      it 'redirects to the root page' do
        create :user

        expect do
          post employees_path, params: { employee: attributes_for(:employee,
                                                                  id_code: 1_111_111_111,
                                                                  patronic_name: 'Testovich',
                                                                  last_name: 'Brown') }
        end.to change(Employee, :count).by(0)

        expect(response).to redirect_to(user_session_path)
      end
    end
  end

  describe 'Employee /edit' do
    context 'when authorized' do
      it 'render successful responce' do
        user = create :user
        employee = create(:employee, id_code: 1_111_111_111,
                                     first_name: 'John',
                                     patronic_name: 'Testovich',
                                     last_name: 'Brown')
        sign_in(user)
        get edit_employee_path(employee.id)

        expect(response).to be_successful
      end
    end

    context 'when unauthorized' do
      it 'redirects to the root page' do
        create :user
        employee = create(:employee, id_code: 1_111_111_111,
                                     first_name: 'John',
                                     patronic_name: 'Testovich',
                                     last_name: 'Brown')
        get edit_employee_path(employee.id)

        expect(response).to_not be_successful
        expect(response).to redirect_to(user_session_path)
      end
    end
  end

  describe 'DELETE /destroy' do
    context 'when user is authorized' do
      it 'deletes a employee' do
        user = create(:user)
        employee = create(:employee, id_code: 1_111_111_111,
                                     first_name: 'John',
                                     patronic_name: 'Testovich',
                                     last_name: 'Brown')
        sign_in(user)

        expect { delete employee_path(employee.id) }.to change(Employee, :count).by(-1)
        expect(response).to redirect_to(employees_path)
      end
    end

    context 'when user unauthorized' do
      it 'does not delete an employee' do
        employee = create(:employee, id_code: 1_111_111_111,
                                     first_name: 'John',
                                     patronic_name: 'Testovich',
                                     last_name: 'Brown')

        expect { delete employee_path(employee.id) }.to change(Employee, :count).by(0)
        expect(response).to redirect_to(user_session_path)
      end
    end
  end
end
