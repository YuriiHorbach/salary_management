# frozen_string_literal: true

# Turns account books into a shared catalog.
#
# Before this migration each +account_books+ row belonged to one employee
# through +account_books.employee_id+, so assigning the same code to another
# employee created a duplicate row. After the migration employees reference a
# catalog book through +employees.account_book_id+ and a code is unique.
#
# Existing assignments are backfilled before the old column is removed. Any
# duplicate codes must be cleaned up manually before the unique index can be
# created; this migration intentionally does not merge data.
class MoveAccountBookReferenceToEmployees < ActiveRecord::Migration[8.0]
  def up
    ensure_unique_codes!

    add_reference :employees, :account_book, foreign_key: { on_delete: :nullify }

    execute <<~SQL.squish
      UPDATE employees
      SET account_book_id = account_books.id
      FROM account_books
      WHERE account_books.employee_id = employees.id
    SQL

    remove_reference :account_books, :employee, foreign_key: true
    add_index :account_books, :code, unique: true
  end

  def down
    remove_index :account_books, :code, unique: true

    add_reference :account_books, :employee, foreign_key: true

    execute <<~SQL.squish
      UPDATE account_books
      SET employee_id = employees.id
      FROM employees
      WHERE employees.account_book_id = account_books.id
    SQL

    remove_reference :employees, :account_book, foreign_key: true
  end

  private

  def ensure_unique_codes!
    duplicates = select_values('SELECT code FROM account_books GROUP BY code HAVING COUNT(*) > 1')
    return if duplicates.empty?

    raise ActiveRecord::MigrationError,
          "Duplicate account book codes found: #{duplicates.join(', ')}. " \
          'Clean them up manually before running this migration.'
  end
end
