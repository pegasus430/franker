class AddFieldsToOrder < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.string :transaction_id
      t.string :customer_id
      t.integer :user_id
      t.integer :total_amount
      t.integer :item_amount
      t.integer :sales_tax_amount
      t.integer :status, default: 0
      t.integer :address_id
      t.timestamps
    end
    add_index :orders, :id
    add_index :orders, :user_id
    add_index :orders, :address_id
    add_index :orders, :created_at
    add_index :orders, :status
    add_index :orders, :total_amount
  end
end