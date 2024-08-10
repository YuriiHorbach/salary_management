class AddColumnToUserTable < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :id_code, :integer, null: false
    add_column :users, :first_name, :string, null: false
    add_column :users, :patronic_name, :string, null: false
    add_column :users, :last_name, :string, null: false
    # add_reference :departments, :department_id, foreign_key: true
    # add_reference :acount_books, :book_id, foreign_key: true
  end
end
