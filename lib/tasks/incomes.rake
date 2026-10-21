# frozen_string_literal: true

namespace :incomes do
  desc 'Recalculate employee_period_incomes for every employee and month'
  task recalculate: :environment do
    employee_count = 0
    aggregate_count = 0

    periods_for = lambda do |employee|
      [
        employee.salaries.pluck(:period),
        employee.vacations.pluck(:period),
        employee.sick_days.pluck(:period)
      ].flatten.compact.map { |period| period.to_date.beginning_of_month }.uniq
    end

    Employee.find_each do |employee|
      employee_count += 1

      periods_for.call(employee).each do |period|
        EmployeePeriodIncome::INCOME_TYPES.each do |income_type|
          aggregate = Incomes::PeriodRecalculator.call(
            employee: employee,
            period: period,
            income_type: income_type
          )
          aggregate_count += 1 if aggregate
        end
      end
    end

    puts "Recalculated #{aggregate_count} aggregates for #{employee_count} employees."
  end
end
