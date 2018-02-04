class AddStoresCategoryIndexes < ActiveRecord::Migration
  def change
    add_index :stores, [:created_at, :active, :id]
    add_index :items, :import_key
    add_index :categories, [:special_tag, :name, :parent_id]
  end
end
