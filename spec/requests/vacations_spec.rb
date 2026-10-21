# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vacations', type: :request do
  let(:employee) { create(:employee) }
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /employees/:employee_id/vacations' do
    it 'calculate vacations with the same sums' do
      create(:vacation, employee: employee, vacation_amount: 5000, period: '2026-02-01')
      create(:vacation, employee: employee, vacation_amount: 5000, period: '2026-02-02')

      get employee_vacations_path(employee)

      expect(response.body).to include('10,000')
      expect(response.body).not_to include('Загальна сума відпускних: ₴5,000')
    end
  end

  describe 'GET /employees/:employee_id/vacations/new' do
    it 'does not prefill the vacation amount and shows the input format hint' do
      get new_employee_vacation_path(employee)

      amount_input = Nokogiri::HTML(response.body).at_css('input[name="vacation[vacation_amount]"]')

      expect(response).to have_http_status(:ok)
      expect(amount_input['value']).to be_blank
      expect(response.body).to include('1000,00')
    end

    context 'when a current working month is selected' do
      let(:user) { create(:user, current_working_month: Date.new(2025, 4, 1)) }

      it 'defaults the vacation period to the current working month' do
        get new_employee_vacation_path(employee)

        period_input = Nokogiri::HTML(response.body).at_css('input[name="vacation[period]"]')

        expect(period_input['value']).to eq('2025-04-01')
      end
    end
  end

  describe 'POST /employees/:employee_id/vacations' do
    let(:valid_attributes) { { period: '2023-01-01', vacation_amount: '100.00' } }

    it 'creates a new vacation' do
      expect do
        post employee_vacations_path(employee), params: { vacation: valid_attributes }
      end.to change(Vacation, :count).by(1)
    end
  end

  describe 'PATCH /employees/:employee_id/vacations/:id' do
    # Додаємо period обов'язково
    let(:vacation) { create(:vacation, employee: employee, period: '2023-01-01', vacation_amount_cents: 10_000) }

    it 'updates the vacation' do
      patch employee_vacation_path(employee, vacation), params: { vacation: { vacation_amount: '150.00' } }
      vacation.reload
      expect(vacation.vacation_amount_cents).to eq(15_000)
    end
  end
end
