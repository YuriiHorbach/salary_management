# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 20_251_111_143_216) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_catalog.plpgsql'

  create_table 'account_books', force: :cascade do |t|
    t.string 'book_name', null: false
    t.bigint 'employee_id'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['employee_id'], name: 'index_account_books_on_employee_id'
  end

  create_table 'bookmarks', force: :cascade do |t|
    t.string 'title'
    t.string 'url'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.bigint 'folder_id', null: false
    t.index ['folder_id'], name: 'index_bookmarks_on_folder_id'
  end

  create_table 'department_employees', force: :cascade do |t|
    t.bigint 'employee_id', null: false
    t.bigint 'department_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.bigint 'position_id'
    t.index ['department_id'], name: 'index_department_employees_on_department_id'
    t.index ['employee_id'], name: 'index_department_employees_on_employee_id'
    t.index ['position_id'], name: 'index_department_employees_on_position_id'
  end

  create_table 'departments', force: :cascade do |t|
    t.string 'name', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'employees', force: :cascade do |t|
    t.bigint 'id_code', null: false
    t.string 'first_name', null: false
    t.string 'patronic_name'
    t.string 'last_name', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.decimal 'total_salary', default: '0.0'
    t.integer 'children_count'
    t.integer 'disability_group'
    t.boolean 'chaes'
  end

  create_table 'folders', force: :cascade do |t|
    t.string 'title'
    t.text 'description'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'positions', force: :cascade do |t|
    t.string 'position_name', null: false
    t.bigint 'department_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['department_id'], name: 'index_positions_on_department_id'
  end

  create_table 'salaries', force: :cascade do |t|
    t.decimal 'amount'
    t.bigint 'employee_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.bigint 'department_id'
    t.datetime 'paid_on', null: false
    t.integer 'income_tax_cents', default: 0, null: false
    t.integer 'military_tax_cents', default: 0, null: false
    t.integer 'net_amount_cents', default: 0, null: false
    t.datetime 'taxes_calculated_at'
    t.index ['department_id'], name: 'index_salaries_on_department_id'
    t.index ['employee_id'], name: 'index_salaries_on_employee_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'email', default: '', null: false
    t.string 'encrypted_password', default: '', null: false
    t.string 'reset_password_token'
    t.datetime 'reset_password_sent_at'
    t.datetime 'remember_created_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['email'], name: 'index_users_on_email', unique: true
    t.index ['reset_password_token'], name: 'index_users_on_reset_password_token', unique: true
  end

  add_foreign_key 'account_books', 'employees'
  add_foreign_key 'bookmarks', 'folders'
  add_foreign_key 'department_employees', 'departments', on_delete: :cascade
  add_foreign_key 'department_employees', 'employees', on_delete: :cascade
  add_foreign_key 'department_employees', 'positions', on_delete: :cascade
  add_foreign_key 'positions', 'departments'
  add_foreign_key 'salaries', 'departments'
  add_foreign_key 'salaries', 'employees'
end
