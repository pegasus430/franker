class AddIndexForForiegnKeysInAllTables < ActiveRecord::Migration
  def change
    add_index :items, [:created_at, :store_id]
    add_index :user_items, [:item_id, :created_at, :user_id]
    add_index :user_favorite_stores, [:created_at, :user_id, :store_id], name: "favorite_stores_index"
    add_index :comments, [:created_at, :item_id, :user_id]
  end
end