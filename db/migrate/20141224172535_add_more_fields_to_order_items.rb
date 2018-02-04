class AddMoreFieldsToOrderItems < ActiveRecord::Migration
  def change
    add_column :order_items, :size, :string
    add_column :order_items, :color, :string
  end
end