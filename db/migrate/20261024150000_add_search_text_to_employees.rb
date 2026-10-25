# frozen_string_literal: true

# Enables pg_trgm extension and adds a search_text column to employees for
# fast case-insensitive substring search of Cyrillic names and ID codes.
#
# pg_trgm is required because PostgreSQL C collation does not fold Cyrillic
# in ILIKE/LOWER. A GIN index with gin_trgm_ops supports LIKE searches on
# search_text via the trigram operator class.
class AddSearchTextToEmployees < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    add_column :employees, :search_text, :text

    add_index :employees, :search_text,
              name: 'index_employees_on_search_text_gin_trgm',
              opclass: :gin_trgm_ops,
              using: :gin,
              algorithm: :concurrently,
              if_not_exists: true

    # Backfill search_text in batches to avoid memory pressure on large tables.
    # Downcase in Ruby because C collation does not fold Cyrillic in SQL LOWER().
    Employee.find_each(batch_size: 1_000) do |employee|
      employee.update_column(:search_text, build_search_text(employee))
    end
  end

  def down
    remove_index :employees, name: 'index_employees_on_search_text_gin_trgm' if index_exists?(:employees, name: 'index_employees_on_search_text_gin_trgm')
    remove_column :employees, :search_text
    disable_extension 'pg_trgm' if extension_enabled?('pg_trgm')
  end

  private

  def build_search_text(employee)
    [
      employee.id_code.to_s,
      employee.last_name.to_s,
      employee.first_name.to_s,
      employee.patronic_name.to_s
    ].compact_blank.join(' ').downcase
  end
end
