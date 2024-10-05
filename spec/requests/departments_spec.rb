# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Departments', type: :request do
  let(:user) { create :user }

  describe 'GET /index' do
    context 'when user is authorized' do
      it 'shows a departments list' do
        user = create(:user)
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
      it 'shows a department page' do
        user = create :user
        department = create(:department)
        sign_in(user)
        get department_path(department.id)

        expect(response).to be_successful
      end
    end

    context 'when unauthorized' do
      it 'redirect to the root_path' do
        create :user
        department = create(:department)
        get department_path(department.id)

        expect(response).to redirect_to(user_session_path)
      end
    end
  end
end
