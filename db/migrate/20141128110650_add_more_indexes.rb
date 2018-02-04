class AddMoreIndexes < ActiveRecord::Migration
  def change
    add_index :users, :email
    add_index :item_lists, :list_id
    add_index :item_lists, :item_id
    add_index :item_lists, [:item_id, :position]
    add_index :user_lists, [:list_id, :user_id]
    add_index :user_lists, :id
    add_index :user_lists, :list_id
    add_index :user_lists, :user_id
  end
end
