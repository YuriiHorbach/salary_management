class FixEmployeeBirthdayColumns < ActiveRecord::Migration[7.1]
  # Legacy data-fix migration. The `birthdate` string column only ever existed in
  # databases that had been imported from a legacy CSV, so only touch it when it
  # is actually present (on a clean database it is absent).
  def up
    if column_exists?(:employees, :birthdate)
      execute <<-SQL
        UPDATE employees
        SET birthday = TO_DATE(birthdate, 'DD.MM.YYYY')
        WHERE birthdate IS NOT NULL AND birthdate != '';
      SQL

      remove_column :employees, :birthdate
    end

    remove_column :employees, :"id_code;last_name;first_name" if column_exists?(:employees,
                                                                                :"id_code;last_name;first_name")
  end

  def down
    unless column_exists?(:employees, :birthdate)
      add_column :employees, :birthdate, :string

      execute <<-SQL
        UPDATE employees
        SET birthdate = TO_CHAR(birthday, 'DD.MM.YYYY')
        WHERE birthday IS NOT NULL;
      SQL
    end
  end
end
