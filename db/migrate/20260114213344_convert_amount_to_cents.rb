class ConvertAmountToCents < ActiveRecord::Migration[8.0]
  def up
    add_column :salaries, :amount_cents, :integer, default: 0, null: false

    execute <<-SQL
      UPDATE salaries
      SET amount_cents = CAST(ROUND(amount * 100) AS INTEGER)
    SQL

    remove_column :salaries, :amount
  end

  def down
    add_column :salaries, :amount, :decimal, precision: 10, scale: 2
    execute 'UPDATE salaries SET amount = amount_cents / 100.0'
    remove_column :salaries, :amount_cents
  end
end
