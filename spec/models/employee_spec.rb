# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Employee, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:employee)).to be_valid
    end

    it 'is invalid without id_code' do
      expect(build(:employee, id_code: nil)).to be_invalid
    end

    it 'is invalid when id_code length is not 10' do
      expect(build(:employee, id_code: 1_111_111_11)).to be_invalid
    end

    it 'is invalid without first_name' do
      expect(build(:employee, first_name: nil)).to be_invalid
    end

    it 'is invalid without last_name' do
      expect(build(:employee, last_name: nil)).to be_invalid
    end

    it 'is invalid without patronic_name' do
      expect(build(:employee, patronic_name: nil)).to be_invalid
    end
  end

  describe '#total_salary' do
    let(:employee) { create(:employee) }

    it 'returns 0 if no salaries' do
      expect(employee.total_salary).to eq(0)
    end

    it 'returns sum of salaries' do
      create(:salary, employee: employee, amount: 100_000)
      create(:salary, employee: employee, amount: 200_000)

      expect(employee.total_salary).to eq(300_000)
    end
  end

  describe "recalculates taxes on attribute change", truncation: true do
    let!(:employee) { create(:employee, children_count: 0, contract: false) }
    let!(:salary) { create(:salary, employee: employee, amount: 700_000, created_at: 5.minutes.ago) }

    it 'recalculates taxes when children_count changes' do
      res_old = TaxCalculator.call(
        amount_cents: salary.amount.to_d, 
        children_count: 0,
        contract: false
      )
      old_tax = res_old[:income_tax_cents]
      
      employee.update!(children_count: 3)

      res_new = TaxCalculator.call(
        amount_cents: salary.amount.to_d, 
        children_count: 3,
        contract: false
      )
      new_tax = res_new[:income_tax_cents]
    
      expect(new_tax).to be < old_tax
    end

    it 'actually updates salary record' do
      TaxCalculationJob.perform_now(salary.id)
      old_tax = salary.reload.income_tax_cents
      
      employee.update!(children_count: 3)
      
      TaxCalculationJob.perform_now(salary.id)
    
      salary.reload
      
      expect(salary.income_tax_cents).to be < old_tax
      expect(salary.income_tax_cents).to eq(44244)
    end
  
    it 'does NOT recalculate taxes when non-tax-affecting attribute changes' do
      TaxCalculationJob.perform_now(salary.id)
      old_tax = salary.reload.income_tax_cents
  
      perform_enqueued_jobs do
        employee.update!(first_name: "NewName")
      end
  
      expect(salary.reload.income_tax_cents).to eq(old_tax)
    end
  end
end