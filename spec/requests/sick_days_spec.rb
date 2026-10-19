# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SickDays', type: :request do
  let(:user) { create(:user) }
  let(:employee) { create(:employee, children_count: 3, chaes: false, disability_group: 0) }

  before do
    sign_in user
  end

  describe 'GET /employees/:employee_id/sick_days' do
    it 'returns a successful response' do
      get employee_sick_days_path(employee)

      expect(response).to have_http_status(:ok)
    end

    context 'when the employee has sick days' do
      before do
        create(:sick_day, employee: employee, pfu_amount_cents: 6_000, enterprise_amount_cents: 4_000,
                          period: Date.new(2026, 1, 1))
      end

      it 'renders the period totals' do
        get employee_sick_days_path(employee)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('РАЗОМ ЗА')
        expect(response.body).to include('$60.00', '$40.00', '$100.00')
      end
    end
  end

  describe 'GET /employees/:employee_id/sick_days/new' do
    it 'renders a form that navigates as a full page instead of targeting a missing frame' do
      get new_employee_sick_day_path(employee)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-turbo-frame="new_sick_day"')
    end
  end

  describe 'POST /employees/:employee_id/sick_days' do
    let(:valid_params) do
      {
        sick_day: {
          pfu_amount_cents: 6_000,
          enterprise_amount_cents: 4_000,
          period: Date.new(2026, 1, 1)
        }
      }
    end

    it 'creates a sick day and stores flat taxes without PSP adjustments' do
      expect do
        post employee_sick_days_path(employee), params: valid_params
      end.to change(SickDay, :count).by(1)

      expect(response).to redirect_to(employee_sick_days_path(employee))

      sick_day = SickDay.last
      expect(sick_day.income_tax_cents).to eq(1_800)
      expect(sick_day.military_tax_cents).to eq(500)
      expect(sick_day.net_amount_cents).to eq(7_700)
    end

    context 'with params sent by the HTML form' do
      it 'accepts monetized amounts and a YYYY-MM period' do
        expect do
          post employee_sick_days_path(employee), params: {
            sick_day: { pfu_amount: '60.00', enterprise_amount: '40.00', period: '2026-10' }
          }
        end.to change(SickDay, :count).by(1)

        expect(response).to redirect_to(employee_sick_days_path(employee))

        sick_day = SickDay.last
        expect(sick_day.period).to eq(Date.new(2026, 10, 1))
        expect(sick_day.pfu_amount_cents).to eq(6_000)
        expect(sick_day.enterprise_amount_cents).to eq(4_000)
        expect(sick_day.income_tax_cents).to eq(1_800)
        expect(sick_day.military_tax_cents).to eq(500)
        expect(sick_day.net_amount_cents).to eq(7_700)
      end
    end

    context 'when income_rate is updated to 20%' do
      before do
        TaxSetting.current.update!(income_rate: 0.20)
      end

      it 'uses the new flat rate for a newly created sick day' do
        post employee_sick_days_path(employee), params: valid_params

        sick_day = SickDay.last
        expect(sick_day.income_tax_cents).to eq(2_000)
        expect(sick_day.military_tax_cents).to eq(500)
        expect(sick_day.net_amount_cents).to eq(7_500)
      end
    end

    context 'with invalid params' do
      it 'does not create a record and re-renders :new with 422' do
        expect do
          post employee_sick_days_path(employee),
               params: { sick_day: { pfu_amount_cents: 6_000, enterprise_amount_cents: 4_000, period: nil } }
        end.not_to change(SickDay, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /employees/:employee_id/sick_days/:id' do
    let!(:sick_day) do
      create(:sick_day, employee: employee, pfu_amount_cents: 6_000, enterprise_amount_cents: 4_000,
                        period: Date.new(2026, 1, 1))
    end

    it 'recalculates the taxes using the flat rates' do
      patch employee_sick_day_path(employee, sick_day),
            params: { sick_day: { pfu_amount_cents: 20_000, enterprise_amount_cents: 10_000 } }

      expect(response).to redirect_to(employee_sick_days_path(employee))

      sick_day.reload
      expect(sick_day.income_tax_cents).to eq(5_400)
      expect(sick_day.military_tax_cents).to eq(1_500)
      expect(sick_day.net_amount_cents).to eq(23_100)
    end

    context 'with params sent by the HTML form' do
      it 'accepts monetized amounts and a YYYY-MM period and recalculates taxes' do
        patch employee_sick_day_path(employee, sick_day), params: {
          sick_day: { pfu_amount: '200.00', enterprise_amount: '100.00', period: '2026-02' }
        }

        expect(response).to redirect_to(employee_sick_days_path(employee))

        sick_day.reload
        expect(sick_day.period).to eq(Date.new(2026, 2, 1))
        expect(sick_day.pfu_amount_cents).to eq(20_000)
        expect(sick_day.enterprise_amount_cents).to eq(10_000)
        expect(sick_day.income_tax_cents).to eq(5_400)
        expect(sick_day.military_tax_cents).to eq(1_500)
        expect(sick_day.net_amount_cents).to eq(23_100)
      end
    end

    context 'with invalid params' do
      it 'does not update the record and re-renders :edit with 422' do
        patch employee_sick_day_path(employee, sick_day),
              params: { sick_day: { period: nil } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(sick_day.reload.period).to be_present
      end
    end
  end

  describe 'DELETE /employees/:employee_id/sick_days/:id' do
    let!(:sick_day) { create(:sick_day, employee: employee, period: Date.new(2026, 1, 1)) }

    it 'deletes the record and redirects to the index' do
      expect do
        delete employee_sick_day_path(employee, sick_day)
      end.to change(SickDay, :count).by(-1)

      expect(response).to redirect_to(employee_sick_days_path(employee))
    end
  end
end
