# frozen_string_literal: true

class AddPeriodToSalaries < ActiveRecord::Migration[8.0]
  def up
    add_column :salaries, :period, :date

    execute <<~SQL.squish
      UPDATE salaries
      SET period = DATE_TRUNC('month', paid_on)::date
      WHERE period IS NULL
    SQL

    merge_duplicate_periods

    change_column_null :salaries, :period, false
    add_index :salaries, %i[employee_id period], unique: true
  end

  def down
    remove_index :salaries, %i[employee_id period]
    remove_column :salaries, :period
  end

  private

  # The old UI allowed several salary records for the same employee and month.
  # Keep a single record per period and preserve the totals by merging the
  # duplicate amounts before the unique index is added.
  def merge_duplicate_periods
    duplicates = select_all(<<~SQL.squish)
      SELECT employee_id, period, MIN(id) AS keep_id,
             SUM(amount_cents) AS amount_cents,
             SUM(income_tax_cents) AS income_tax_cents,
             SUM(military_tax_cents) AS military_tax_cents,
             SUM(net_amount_cents) AS net_amount_cents
      FROM salaries
      GROUP BY employee_id, period
      HAVING COUNT(*) > 1
    SQL

    duplicates.each do |row|
      execute <<~SQL.squish
        UPDATE salaries
        SET amount_cents = #{row['amount_cents'].to_i},
            income_tax_cents = #{row['income_tax_cents'].to_i},
            military_tax_cents = #{row['military_tax_cents'].to_i},
            net_amount_cents = #{row['net_amount_cents'].to_i}
        WHERE id = #{row['keep_id'].to_i}
      SQL

      execute <<~SQL.squish
        DELETE FROM salaries
        WHERE employee_id = #{row['employee_id'].to_i}
          AND period = #{connection.quote(row['period'])}
          AND id <> #{row['keep_id'].to_i}
      SQL
    end
  end
end
