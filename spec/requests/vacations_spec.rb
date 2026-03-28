require 'rails_helper'

RSpec.describe "Vacations", type: :request do
  let(:employee) { create(:employee) }
  let(:vacation) { create(:vacation, employee: employee, period: '2023-01-01') } # Added period
  let(:user) { create(:user) } # Assuming you have a User model and factory

  before do
    sign_in user # Assuming you are using Devise or a similar authentication system
  end

  describe "GET /employees/:employee_id/vacations" do
    it "returns a successful response" do
      get employee_vacations_path(employee)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /employees/:employee_id/vacations/new" do
    it "returns a successful response" do
      get new_employee_vacation_path(employee)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /employees/:employee_id/vacations" do
    let(:valid_attributes) { attributes_for(:vacation, employee: nil, period: '2023-01-01') } # Added period

    context "with valid attributes" do
      before do
        allow(TaxCalculator).to receive(:call).and_return({ income_tax_cents: 1800, military_tax_cents: 500, net_amount_cents: 7700 })
      end

      it "creates a new vacation" do
        expect do
          post employee_vacations_path(employee), params: { vacation: valid_attributes }
        end.to change(Vacation, :count).by(1)
      end

      it "redirects to the employee's vacations list" do
        post employee_vacations_path(employee), params: { vacation: valid_attributes }
        expect(response).to redirect_to(employee_vacations_path(employee))
      end
    end

    context "with invalid attributes" do
      let(:invalid_attributes) { attributes_for(:vacation, vacation_amount_cents: -100, employee: nil, period: '2023-01-01') } # Added period

      it "does not create a new vacation" do
        expect do
          post employee_vacations_path(employee), params: { vacation: invalid_attributes }
        end.not_to change(Vacation, :count)
      end

      it "renders the new vacation form with an error message" do
        post employee_vacations_path(employee), params: { vacation: invalid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /employees/:employee_id/vacations/:id/edit" do
    it "returns a successful response" do
      get edit_employee_vacation_path(employee, vacation)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /employees/:employee_id/vacations/:id" do
    let(:valid_attributes) { { vacation_amount_cents: 15000 } } # 150.00
    let(:invalid_attributes) { { vacation_amount_cents: -50 } }

    context "with valid attributes" do
      before do
        allow(TaxCalculator).to receive(:call).and_return({ income_tax_cents: 2700, military_tax_cents: 750, net_amount_cents: 11550 })
      end

      it "updates the vacation" do
        patch employee_vacation_path(employee, vacation), params: { vacation: valid_attributes }
        vacation.reload
        expect(vacation.vacation_amount_cents).to eq(15000)
      end

      it "redirects to the employee's vacations list" do
        patch employee_vacation_path(employee, vacation), params: { vacation: valid_attributes }
        expect(response).to redirect_to(employee_vacations_path(employee))
      end
    end

    context "with invalid attributes" do
      it "does not update the vacation" do
        patch employee_vacation_path(employee, vacation), params: { vacation: invalid_attributes }
        vacation.reload
        expect(vacation.vacation_amount_cents).not_to eq(-50)
      end

      it "renders the edit vacation form with an error message" do
        patch employee_vacation_path(employee, vacation), params: { vacation: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe "DELETE /employees/:employee_id/vacations/:id" do
    it "destroys the vacation" do
      expect do
        delete employee_vacation_path(employee, vacation)
      end.to change(Vacation, :count).by(-1)
    end

    it "redirects to the employee's vacations list" do
      delete employee_vacation_path(employee, vacation)
      expect(response).to redirect_to(employee_vacations_path(employee))
    end
  end
end
