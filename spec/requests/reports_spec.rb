# frozen_string_literal: true

# spec/controllers/reports_controller_spec.rb
require 'rails_helper'

RSpec.describe ReportsController, type: :controller do
  let(:user) { create(:user) }
  let(:department_a) { create(:department, name: 'Marketing') }
  let(:department_b) { create(:department, name: 'Development') }

  describe 'GET #index' do
    context 'when user is not logged in' do
      it 'redirects to the login page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is logged in' do
      before { sign_in user }

      let!(:salary_record) do
        create(:salary,
               department: department_a,
               amount: 1000,
               net_amount_cents: 80_000,
               income_tax_cents: 18_000,
               military_tax_cents: 2000)
      end

      it 'returns a successful response' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns @q for Ransack' do
        get :index
        expect(assigns(:q)).to be_a(Ransack::Search)
      end

      it 'assigns @total_records with correct Gross Total' do
        get :index
        expect(assigns(:total_records)[:gross]).to eq(100_000)
      end

      it 'assigns @monthly_department_salaries with department data' do
        get :index
        report_data = assigns(:monthly_department_salaries)

        expect(report_data.keys).to include('Marketing')

        expect(report_data['Marketing'][:net]).to eq(80_000)
      end
    end

    context 'when filtering parameters are provided' do
      before { sign_in user }

      let!(:salary_dev) do
        create(:salary, department: department_b, paid_on: '2025-01-15', amount: 5000,
                        net_amount_cents: 400_000)
      end
      let!(:salary_marketing) do
        create(:salary, department: department_a, paid_on: '2025-02-15', amount: 2000,
                        net_amount_cents: 150_000)
      end

      it 'filters by department ID correctly' do
        get :index, params: { q: { by_department: department_a.id } }

        report_data = assigns(:monthly_department_salaries)

        expect(report_data.keys).to contain_exactly('Marketing')

        total_records = assigns(:total_records)
        expect(total_records[:net]).to eq(150_000)
      end

      it 'filters by month and year correctly' do
        get :index, params: { q: { by_month: 1, by_year: 2025 } }

        report_data = assigns(:monthly_department_salaries)

        expect(report_data.keys).to contain_exactly('Development')

        total_records = assigns(:total_records)
        expect(total_records[:gross]).to eq(500_000)
      end
    end
  end
end
