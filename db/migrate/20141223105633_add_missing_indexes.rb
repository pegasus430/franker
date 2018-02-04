class AddMissingIndexes < ActiveRecord::Migration
  def change
    add_index :item_colors, :id
    add_index :item_colors, :item_id
    add_index :item_colors, :sizes
    add_index :item_colors, :image_id
    add_index :images, :imageable_id
    add_index :images, :imageable_type
    add_index :images, :file
    add_index :stores, :created_at
    add_index :stores, :active
    add_index :stores, :position
    add_index :categories, :special_tag
    add_index :categories, :name
  end
end
