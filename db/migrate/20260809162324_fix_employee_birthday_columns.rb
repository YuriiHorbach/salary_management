class FixEmployeeBirthdayColumns < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      UPDATE employees
      SET birthday = TO_DATE(birthdate, 'DD.MM.YYYY')
      WHERE birthdate IS NOT NULL AND birthdate != '';
    SQL

    remove_column :employees, :birthdate
    remove_column :employees, :"id_code;last_name;first_name" if column_exists?(:employees,
                                                                                :"id_code;last_name;first_name")
  end

  def down
    add_column :employees, :birthdate, :string

    execute <<-SQL
      UPDATE employees
      SET birthdate = TO_CHAR(birthday, 'DD.MM.YYYY')
      WHERE birthday IS NOT NULL;
    SQL
  end
end
