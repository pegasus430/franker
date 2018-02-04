class AddBooleanValuesToItems < ActiveRecord::Migration
  def change
    add_column :items, :new_one, :boolean, :default => false
    add_column :items, :trending, :boolean, :default => false
  end
end