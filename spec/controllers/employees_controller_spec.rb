require 'rails_helper'

RSpec.describe 'Employees', type: :request do
  let(:user) { create(:user) }
  let(:employee) { create(:employee) }
  let!(:salary1) { create(:salary, employee: employee, amount: 100, paid_on: Date.new(2025, 5, 1)) }
  let!(:salary2) { create(:salary, employee: employee, amount: 200, paid_on: Date.new(2025, 6, 1)) }

  before { sign_in user, scope: :user }

  describe 'GET /employees/:id' do
    it 'assigns @monthly_totals with correct sums' do
      get employee_path(employee)
      expect(assigns(:monthly_totals)).to include('2025-05' => 100, '2025-06' => 200)
    end

    it 'filters @monthly_totals by month param' do
      get employee_path(employee), params: { month: '5' }
      expect(assigns(:monthly_totals).keys).to include('2025-05')
      expect(assigns(:monthly_totals).keys).not_to include('2025-06')
    end

    it 'filters @monthly_totals by year param' do
      get employee_path(employee), params: { year: '2025' }
      expect(assigns(:monthly_totals).keys).to include('2025-05', '2025-06')
    end
  end
end
