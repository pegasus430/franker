class AddFieldsToOrderItems < ActiveRecord::Migration
  def change
    create_table :order_items do |t|
      t.integer :item_id
      t.integer :order_id
      t.integer :quantity
      t.text :item_data

      t.timestamps
    end
    add_index :order_items, :id
    add_index :order_items, :order_id
    add_index :order_items, :created_at
    add_index :order_items, :item_id
  end
end