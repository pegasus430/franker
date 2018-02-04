class AddAdditionalIndexes < ActiveRecord::Migration
  def change
    add_index :items, :store_id
    add_index :stores, [:created_at, :active]
    add_index :stores, [:created_at, :active, :id, :position]
    add_index :categories, [:special_tag, :parent_id]
    add_index :categories, [:name, :parent_id]
    add_index :lists, [:active, :id, :created_at]
    add_index :item_lists, :id
  end
end
