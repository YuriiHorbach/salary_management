# frozen_string_literal: true

module Salaries
  # Recalculates and persists the per-record tax columns of a single salary.
  #
  # The authoritative taxes for a period are aggregated by
  # +Incomes::PeriodRecalculator+. This service only refreshes the stored
  # per-salary values used for display, so it is safe to call once per record.
  class TaxRecalculator
    # @param salary [Salary] salary whose tax columns are refreshed
    # @return [void]
    def self.call(salary)
      new(salary).call
    end

    # @param salary [Salary]
    def initialize(salary)
      @salary = salary
    end

    # Locks the salary, recalculates its taxes and writes the columns without
    # triggering the salary callbacks again.
    #
    # @return [void]
    def call
      @salary.with_lock do
        persist(tax_result)
      end
    end

    private

    def tax_result
      TaxCalculator.call(
        amount_cents: @salary.amount_cents,
        children_count: @salary.employee.children_count.to_i,
        disability_group: @salary.employee.disability_group.to_i,
        chaes: @salary.employee.chaes || false,
        contract: @salary.employee.contract || false
      )
    end

    def persist(result)
      # rubocop:disable Rails/SkipsModelValidations -- callbacks must not re-enqueue recalculation
      @salary.update_columns(
        income_tax_cents: result[:income_tax_cents],
        military_tax_cents: result[:military_tax_cents],
        net_amount_cents: result[:net_amount_cents],
        updated_at: Time.current
      )
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
