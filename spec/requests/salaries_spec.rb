# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Salaries', type: :request do
  let(:urls) { Rails.application.routes.url_helpers }

  let(:user) { create(:user) }
  let(:employee) { create(:employee) }
  let(:department) { create(:department) }

  let(:valid_attributes) do
    {
      amount_cents: 5000,
      paid_on: '2025-10-01',
      department_id: department.id
    }
  end

  before { sign_in user }

  describe 'GET /new' do
    it 'works' do
      get urls.new_employee_salary_path(employee)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /create' do
    it 'creates a salary' do
      post urls.employee_salaries_path(employee), params: { salary: valid_attributes.except(:department_id), department_id: department.id }
      expect(response).to have_http_status(:found)
    end
  end
end
