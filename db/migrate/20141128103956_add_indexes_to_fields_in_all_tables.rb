class AddIndexesToFieldsInAllTables < ActiveRecord::Migration
  def change
    add_index :users, :uuid
    add_index :users, :imei
    add_index :user_favorite_stores, :user_id
    add_index :user_favorite_stores, :store_id
    add_index :user_favorite_stores, :favorite
    add_index :user_items, :item_id
    add_index :user_items, :user_id
    add_index :user_items, :favorite
    add_index :user_items, :sale
    add_index :items, :new_one
    add_index :items, :active
    add_index :items, :sold_out
    add_index :user_items, :seen
    add_index :categories, :id
    add_index :categories, :parent_id
    add_index :categories, :store_id
    add_index :categories, :category_type


  end
end