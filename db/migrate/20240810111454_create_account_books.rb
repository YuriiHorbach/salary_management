# frozen_string_literal: true

class CreateAccountBooks < ActiveRecord::Migration[7.1]
  def change
    create_table :account_books do |t|
      t.string :book_name, null: false
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
