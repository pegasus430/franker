class AddFieldsToAddress < ActiveRecord::Migration
  def change
    create_table :addresses do |t|
      t.string :full_name
      t.string :zipcode
      t.text :street_address
      t.string :apt_no

      t.timestamps
    end
    add_index :addresses, :id
    add_index :addresses, :zipcode
  end
end
