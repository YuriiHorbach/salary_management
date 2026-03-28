require 'rails_helper'

RSpec.describe "Vacations", type: :request do
  let(:employee) { create(:employee) }
  let(:vacation) { create(:vacation, employee: employee) }
  let(:user) { create(:user) } # Assuming you have a User model and factory

  before do
    sign_in user # Assuming you are using Devise or a similar authentication system
  end

  describe "GET /employees/:employee_id/vacations" do
    it "returns a successful response" do
      get employee_vacations_path(employee)
      expect(response).to have_http_status(:ok)
    end

    it "displays the employee's vacations" do
      vacation # create the vacation
      get employee_vacations_path(employee)
      expect(response.body).to include(I18n.t('vacations.index.title', last_name: employee.last_name, first_name: employee.first_name))
      expect(response.body).to include(vacation.period.strftime('%Y-%m-%d'))
      expect(response.body).to include(number_to_currency(vacation.vacation_amount))
    end

    it "displays a message if there are no vacations" do
      get employee_vacations_path(employee)
      expect(response.body).to include(I18n.t('vacations.index.no_vacations'))
    end
  end

  describe "GET /employees/:employee_id/vacations/new" do
    it "returns a successful response" do
      get new_employee_vacation_path(employee)
      expect(response).to have_http_status(:ok)
    end

    it "renders the new vacation form" do
      get new_employee_vacation_path(employee)
      expect(response.body).to include(I18n.t('vacations.new.title', last_name: employee.last_name, first_name: employee.first_name))
      expect(response.body).to include('input type="date"')
      expect(response.body).to include('input type="number"')
      expect(response.body).to include(I18n.t('shared.forms.save'))
    end
  end

  describe "POST /employees/:employee_id/vacations" do
    let(:valid_attributes) { attributes_for(:vacation, employee: nil) } # employee: nil because it's set by the route

    context "with valid attributes" do
      before do
        allow(TaxCalculator).to receive(:call).and_return({ income_tax_cents: 1800, military_tax_cents: 500, net_amount_cents: 7700 })
      end

      it "creates a new vacation" do
        expect do
          post employee_vacations_path(employee), params: { vacation: valid_attributes }
        end.to change(Vacation, :count).by(1)
      end

      it "redirects to the vacations index page with a notice" do
        post employee_vacations_path(employee), params: { vacation: valid_attributes }
        expect(response).to redirect_to(employee_vacations_path(employee))
        expect(flash[:notice]).to eq('Відпустку успішно додано.')
      end
    end

    context "with invalid attributes" do
      let(:invalid_attributes) { attributes_for(:vacation, vacation_amount_cents: -100, employee: nil) }

      it "does not create a new vacation" do
        expect do
          post employee_vacations_path(employee), params: { vacation: invalid_attributes }
        end.not_to change(Vacation, :count)
      end

      it "renders the new vacation form with an error message" do
        post employee_vacations_path(employee), params: { vacation: invalid_attributes }
        expect(response).to render_template(:new)
        expect(response.body).to include(I18n.t('errors.messages.greater_than_or_equal_to', count: 0))
      end
    end
  end

  describe "GET /employees/:employee_id/vacations/:id/edit" do
    it "returns a successful response" do
      get edit_employee_vacation_path(employee, vacation)
      expect(response).to have_http_status(:ok)
    end

    it "renders the edit vacation form" do
      get edit_employee_vacation_path(employee, vacation)
      expect(response.body).to include(I18n.t('vacations.edit.title', last_name: employee.last_name, first_name: employee.first_name))
      expect(response.body).to include('input type="date"')
      expect(response.body).to include('input type="number"')
      expect(response.body).to include(I18n.t('shared.forms.save'))
      expect(response.body).to include(I18n.t('vacations.edit.delete_button'))
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

      it "redirects to the vacations index page with a notice" do
        patch employee_vacation_path(employee, vacation), params: { vacation: valid_attributes }
        expect(response).to redirect_to(employee_vacations_path(employee))
        expect(flash[:notice]).to eq('Відпустку успішно оновлено.')
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
        expect(response.body).to include(I18n.t('errors.messages.greater_than_or_equal_to', count: 0))
      end
    end
  end

  describe "DELETE /employees/:employee_id/vacations/:id" do
    it "destroys the vacation" do
      expect do
        delete employee_vacation_path(employee, vacation)
      end.to change(Vacation, :count).by(-1)
    end

    it "redirects to the vacations index page with a notice" do
      delete employee_vacation_path(employee, vacation)
      expect(response).to redirect_to(employee_vacations_path(employee))
      expect(flash[:notice]).to eq('Відпустку успішно видалено.')
    end
  end
end
