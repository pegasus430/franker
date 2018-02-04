class CreateItemLists < ActiveRecord::Migration
  def change
    create_table :item_lists do |t|
      t.integer :item_id
      t.integer :list_id
      t.string :quote
      t.integer :position
    end
  end
end
