class CreateTerritorySigns < ActiveRecord::Migration[8.0]
  def change
    create_table :territory_signs do |t|
      t.string :name

      t.timestamps
    end
    add_index :territory_signs, :name
  end
end
