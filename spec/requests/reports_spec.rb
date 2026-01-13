# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Reports", type: :request do
  let(:user) { create(:user) }
  let(:department_a) { create(:department, name: 'Marketing') }
  let(:department_b) { create(:department, name: 'Development') }

  before do 
    sign_in user, scope: :user
    Salary.delete_all 
  end

  describe "GET /reports" do
    context "when user is logged in" do
      it "renders the report with correct total amounts" do
        create(:salary, 
               department: department_a, 
               amount: 10_000,
               income_tax_cents: 180_000,
               military_tax_cents: 15_000,
               net_amount_cents: 805_000)
      
        get reports_path
      
        expect(response).to have_http_status(:success)
        expect(response.body).to include("10,000")
        expect(response.body).to include("1,800")
        expect(response.body).to include("150")
        expect(response.body).to include("8,050")
      end
    end

    context "filtering" do
      it "filters by department correctly" do
        create(:salary, department: department_b, amount: 5_000, paid_on: '2025-01-15')
        create(:salary, department: department_a, amount: 2_000, paid_on: '2025-02-15')

        get reports_path, params: { q: { by_department: department_a.id } }

        expect(response.body).to include("Marketing")
        expect(response.body).to include("2,000")
        expect(response.body).not_to include("5,000") # Перевіряємо, що суми іншого відділу немає
      end
    end
  end
end