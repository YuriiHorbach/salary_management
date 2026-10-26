# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecalculateEmployeeTaxes do
  before { ActiveJob::Base.queue_adapter = :test }

  let(:employee) { create(:employee) }
  let(:period) { Date.current.beginning_of_month }

  it 'enqueues one job per employee and period' do
    create(:salary, employee: employee, period: period, paid_on: period)

    expect do
      described_class.call(employee)
    end.to have_enqueued_job(EmployeeTaxRecalculationJob)
      .with(employee.id, period).exactly(:once)
  end

  it 'does nothing when the employee has no salary in the current month' do
    old_period = period - 1.month
    create(:salary, employee: employee, period: old_period, paid_on: old_period)

    expect do
      described_class.call(employee)
    end.not_to have_enqueued_job(EmployeeTaxRecalculationJob)
  end
end
