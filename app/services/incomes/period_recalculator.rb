# frozen_string_literal: true

require 'digest'

module Incomes
  # Recalculates the aggregated income and taxes for one employee, one month and
  # one income type.
  #
  # Salary amounts are summed across every department and position, vacation
  # amounts are summed separately, and sick-day amounts are summed separately.
  # The resulting gross is passed to +TaxCalculator+ exactly once, so the
  # progressive rules and thresholds apply to the whole period instead of each
  # individual record. The result is upserted into +EmployeePeriodIncome+.
  #
  # Used by the callbacks in +Salary+, +Vacation+ and +SickDay+, and by
  # +TaxCalculationJob+.
  class PeriodRecalculator
    INCOME_TYPES = EmployeePeriodIncome::INCOME_TYPES

    # @param employee [Employee] employee whose income is aggregated
    # @param period [Date, String] any date inside the target month
    # @param income_type [String] one of +EmployeePeriodIncome::INCOME_TYPES+
    # @return [EmployeePeriodIncome, nil] the persisted aggregate, or nil when
    #   the period has no records for the given income type
    def self.call(employee:, period:, income_type:)
      new(employee: employee, period: period, income_type: income_type).call
    end

    def initialize(employee:, period:, income_type:)
      @employee = employee
      @period = normalize_period(period)
      @income_type = income_type.to_s
    end

    def call
      validate_income_type!

      records = taxable_records
      return destroy_aggregate if records.empty?

      gross_cents = records.sum { |record| gross_cents_for(record) }
      result = TaxCalculator.call(amount_cents: gross_cents, **calculator_options)
      aggregate = EmployeePeriodIncome.find_or_initialize_by(
        employee: @employee,
        period: @period,
        income_type: @income_type
      )

      aggregate.update!(
        gross_cents: gross_cents,
        income_tax_cents: result[:income_tax_cents],
        military_tax_cents: result[:military_tax_cents],
        net_amount_cents: result[:net_amount_cents],
        tax_settings_digest: tax_settings_digest
      )

      aggregate
    end

    private

    def normalize_period(period)
      period.to_date.beginning_of_month
    end

    def validate_income_type!
      return if INCOME_TYPES.include?(@income_type)

      raise ArgumentError, "Unknown income type: #{@income_type.inspect}"
    end

    # Vacation and sick-day rows may be dated on any day of the month, so their
    # records are selected with a full-month range.
    def taxable_records
      case @income_type
      when 'salary' then @employee.salaries.where(period: @period)
      when 'vacation' then @employee.vacations.where(period: @period.all_month)
      when 'sick_day' then @employee.sick_days.where(period: @period.all_month)
      end
    end

    def gross_cents_for(record)
      case @income_type
      when 'salary' then record.amount_cents.to_i
      when 'vacation' then record.vacation_amount_cents.to_i
      when 'sick_day' then record.pfu_amount_cents.to_i + record.enterprise_amount_cents.to_i
      end
    end

    def calculator_options
      return { simple: true } unless @income_type == 'salary'

      {
        children_count: @employee.children_count.to_i,
        disability_group: @employee.disability_group.to_i,
        chaes: @employee.chaes || false,
        contract: @employee.contract || false
      }
    end

    def destroy_aggregate
      EmployeePeriodIncome.where(
        employee: @employee,
        period: @period,
        income_type: @income_type
      ).destroy_all

      nil
    end

    def tax_settings_digest
      settings = TaxSetting.current
      attributes = settings.slice(:income_rate, :military_rate, :gran_dohid_uah, :psp_uah)

      Digest::SHA256.hexdigest(attributes.to_json)
    end
  end
end
