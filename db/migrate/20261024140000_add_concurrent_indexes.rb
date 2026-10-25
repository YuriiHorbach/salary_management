# frozen_string_literal: true

# Adds concurrent indexes to support read-heavy report queries and enforce
# model-level uniqueness at the database level.
#
# All indexes use `algorithm: :concurrently` and `if_not_exists: true` so they
# can be applied without blocking reads/writes on the agent database. The
# migration runs outside a DDL transaction (`disable_ddl_transaction!`) because
# `CREATE INDEX CONCURRENTLY` cannot run inside a transaction.
class AddConcurrentIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # --- department_employees ---
    # Model validation: employee_id unique within (department_id, position_id).
    # PostgreSQL treats NULL as distinct in unique indexes, so we need two
    # partial indexes to fully mirror the Rails validation.
    add_index :department_employees,
              %i[employee_id department_id position_id],
              unique: true,
              where: 'position_id IS NOT NULL',
              name: 'index_department_employees_on_emp_dept_pos_not_null',
              algorithm: :concurrently,
              if_not_exists: true

    add_index :department_employees,
              %i[employee_id department_id],
              unique: true,
              where: 'position_id IS NULL',
              name: 'index_department_employees_on_emp_dept_pos_null',
              algorithm: :concurrently,
              if_not_exists: true

    # --- salaries ---
    # Reports filter/group by period heavily.
    add_index :salaries, :period,
              name: 'index_salaries_on_period',
              algorithm: :concurrently,
              if_not_exists: true

    # --- sick_days ---
    # Reports filter/group by period heavily.
    add_index :sick_days, :period,
              name: 'index_sick_days_on_period',
              algorithm: :concurrently,
              if_not_exists: true

    # --- vacations ---
    # Reports filter/group by period heavily.
    add_index :vacations, :period,
              name: 'index_vacations_on_period',
              algorithm: :concurrently,
              if_not_exists: true

    # --- employee_period_incomes ---
    # Summary report filters by period on every call.
    add_index :employee_period_incomes, :period,
              name: 'index_employee_period_incomes_on_period',
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :salaries, name: 'index_salaries_on_period' if index_exists?(:salaries, name: 'index_salaries_on_period')
    remove_index :sick_days, name: 'index_sick_days_on_period' if index_exists?(:sick_days, name: 'index_sick_days_on_period')
    remove_index :vacations, name: 'index_vacations_on_period' if index_exists?(:vacations, name: 'index_vacations_on_period')
    remove_index :employee_period_incomes, name: 'index_employee_period_incomes_on_period' if index_exists?(:employee_period_incomes, name: 'index_employee_period_incomes_on_period')
    remove_index :department_employees, name: 'index_department_employees_on_emp_dept_pos_not_null' if index_exists?(:department_employees, name: 'index_department_employees_on_emp_dept_pos_not_null')
    remove_index :department_employees, name: 'index_department_employees_on_emp_dept_pos_null' if index_exists?(:department_employees, name: 'index_department_employees_on_emp_dept_pos_null')
  end
end
