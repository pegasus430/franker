class AddIndexingToAllTables < ActiveRecord::Migration
  def change
    add_index :items, :id
    add_index :notifications, :id
    add_index :user_items, :id
    add_index :users, :id
    add_index :stores, :id
    add_index :categories, [:id, :parent_id, :store_id]
    add_index :user_favorite_stores, :id
  end
end