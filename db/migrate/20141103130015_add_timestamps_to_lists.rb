class AddTimestampsToLists < ActiveRecord::Migration
  def change
    add_column(:lists, :created_at, :datetime)
    add_column(:lists, :updated_at, :datetime)
    add_column(:user_lists, :created_at, :datetime)
    add_column(:user_lists, :updated_at, :datetime)
    add_column(:item_lists, :created_at, :datetime)
    add_column(:item_lists, :updated_at, :datetime)

    add_index :lists, [:id]
    add_index :user_lists, [:id, :user_id, :list_id]
    add_index :item_lists, [:id, :list_id, :item_id]
  end
end