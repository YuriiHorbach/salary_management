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

ActiveRecord::Schema[8.0].define(version: 2026_10_27_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "account_books", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.index ["code"], name: "index_account_books_on_code", unique: true
  end

  create_table "application_settings", force: :cascade do |t|
    t.string "default_locale", default: "en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bookmarks", force: :cascade do |t|
    t.string "title"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "folder_id", null: false
    t.index ["folder_id"], name: "index_bookmarks_on_folder_id"
  end

  create_table "department_employees", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "department_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "position_id"
    t.index ["department_id"], name: "index_department_employees_on_department_id"
    t.index ["employee_id", "department_id", "position_id"], name: "index_department_employees_on_emp_dept_pos_not_null", unique: true, where: "(position_id IS NOT NULL)"
    t.index ["employee_id", "department_id"], name: "index_department_employees_on_emp_dept_pos_null", unique: true, where: "(position_id IS NULL)"
    t.index ["employee_id"], name: "index_department_employees_on_employee_id"
    t.index ["position_id"], name: "index_department_employees_on_position_id"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "employee_period_incomes", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "period", null: false
    t.string "income_type", null: false
    t.integer "gross_cents", default: 0, null: false
    t.integer "income_tax_cents", default: 0, null: false
    t.integer "military_tax_cents", default: 0, null: false
    t.integer "net_amount_cents", default: 0, null: false
    t.string "tax_settings_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "period", "income_type"], name: "index_employee_period_incomes_unique", unique: true
    t.index ["employee_id"], name: "index_employee_period_incomes_on_employee_id"
    t.index ["period"], name: "index_employee_period_incomes_on_period"
  end

  create_table "employees", force: :cascade do |t|
    t.string "id_code", null: false
    t.string "first_name", null: false
    t.string "patronic_name"
    t.string "last_name", null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.datetime "updated_at", default: -> { "now()" }, null: false
    t.integer "children_count"
    t.integer "disability_group"
    t.boolean "chaes"
    t.string "territory_info", default: "", null: false
    t.boolean "contract", default: false
    t.date "birthday"
    t.bigint "territory_sign_id"
    t.string "identifier"
    t.text "search_text"
    t.bigint "account_book_id"
    t.string "page_number"
    t.index ["account_book_id"], name: "index_employees_on_account_book_id"
    t.index ["id_code"], name: "index_employees_on_id_code", unique: true
    t.index ["identifier"], name: "index_employees_on_identifier"
    t.index ["search_text"], name: "index_employees_on_search_text_gin_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["territory_sign_id"], name: "index_employees_on_territory_sign_id"
  end

  create_table "folders", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "positions", force: :cascade do |t|
    t.string "position_name", null: false
    t.bigint "department_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_positions_on_department_id"
  end

  create_table "salaries", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_id"
    t.datetime "paid_on", null: false
    t.integer "income_tax_cents", default: 0, null: false
    t.integer "military_tax_cents", default: 0, null: false
    t.integer "net_amount_cents", default: 0, null: false
    t.datetime "taxes_calculated_at"
    t.integer "amount_cents", default: 0, null: false
    t.date "period", null: false
    t.bigint "position_id"
    t.index ["department_id"], name: "index_salaries_on_department_id"
    t.index ["employee_id", "period", "department_id"], name: "index_salaries_unique_department_per_period", unique: true, where: "(position_id IS NULL)"
    t.index ["employee_id", "period", "position_id"], name: "index_salaries_unique_position_per_period", unique: true, where: "(position_id IS NOT NULL)"
    t.index ["employee_id"], name: "index_salaries_on_employee_id"
    t.index ["period"], name: "index_salaries_on_period"
    t.index ["position_id"], name: "index_salaries_on_position_id"
  end

  create_table "sick_days", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.integer "pfu_amount_cents", default: 0, null: false
    t.integer "enterprise_amount_cents", default: 0, null: false
    t.date "period", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "income_tax_cents", default: 0, null: false
    t.integer "military_tax_cents", default: 0, null: false
    t.integer "net_amount_cents", default: 0, null: false
    t.bigint "department_id"
    t.index ["department_id"], name: "index_sick_days_on_department_id"
    t.index ["employee_id"], name: "index_sick_days_on_employee_id"
    t.index ["period"], name: "index_sick_days_on_period"
  end

  create_table "tax_settings", force: :cascade do |t|
    t.decimal "income_rate", precision: 6, scale: 4, null: false
    t.decimal "military_rate", precision: 6, scale: 4, null: false
    t.decimal "gran_dohid_uah", precision: 10, scale: 2, null: false
    t.decimal "psp_uah", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "territory_signs", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_territory_signs_on_name"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "current_working_month"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vacations", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.integer "vacation_amount_cents", default: 0, null: false
    t.date "period", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "income_tax_cents"
    t.integer "military_tax_cents"
    t.integer "net_amount_cents"
    t.bigint "department_id"
    t.index ["department_id"], name: "index_vacations_on_department_id"
    t.index ["employee_id"], name: "index_vacations_on_employee_id"
    t.index ["period"], name: "index_vacations_on_period"
  end

  add_foreign_key "bookmarks", "folders"
  add_foreign_key "department_employees", "departments", on_delete: :cascade
  add_foreign_key "department_employees", "employees", on_delete: :cascade
  add_foreign_key "department_employees", "positions", on_delete: :cascade
  add_foreign_key "employee_period_incomes", "employees", on_delete: :cascade
  add_foreign_key "employees", "account_books", on_delete: :nullify
  add_foreign_key "employees", "territory_signs"
  add_foreign_key "positions", "departments"
  add_foreign_key "salaries", "departments"
  add_foreign_key "salaries", "employees"
  add_foreign_key "salaries", "positions", on_delete: :nullify
  add_foreign_key "sick_days", "departments"
  add_foreign_key "sick_days", "employees"
  add_foreign_key "vacations", "departments"
  add_foreign_key "vacations", "employees"
end
