# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaxCalculationJob, type: :job do
  let(:employee) { create(:employee) }
  let!(:salary) { create(:salary, employee: employee, amount: 1_000.00, paid_on: Date.today) }

  describe '#perform' do
    it 'calculates taxes and updates salary record' do
      perform_enqueued_jobs do
        TaxCalculationJob.perform_later(salary.id)
      end

      salary.reload

      expect(salary.income_tax_cents).to be_present
      expect(salary.military_tax_cents).to be_present
      expect(salary.net_amount_cents).to be_present

      # Перевіряємо конкретні значення
      # Для 1000 UAH (100_000 копійок) без дітей і інвалідності:
      # - брутто: 100_000
      # - ПДФО: 0 (менше за PSP = 151_400)
      # - ВЗ: 100_000 * 0.05 = 5_000
      # - чисто: 100_000 - 0 - 5_000 = 98_500
      expect(salary.income_tax_cents).to eq 0
      expect(salary.military_tax_cents).to eq 5_000
      expect(salary.net_amount_cents).to eq 95_000
    end

    it 'handles missing salary gracefully (job doesnt crash)' do
      # Запускаємо job з неіснуючим id
      expect do
        perform_enqueued_jobs do
          TaxCalculationJob.perform_later(999_999)
        end
      end.not_to raise_error
    end

    it 'enqueues job when salary is created' do
      # Перевіряємо що при створенні зарплати job ставиться в чергу
      expect do
        create(:salary, employee: employee, amount: 500.0)
      end.to have_enqueued_job(TaxCalculationJob)
    end
  end
end
