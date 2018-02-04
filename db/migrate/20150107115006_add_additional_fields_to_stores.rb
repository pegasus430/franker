class AddAdditionalFieldsToStores < ActiveRecord::Migration
  def change
    add_column :stores, :shipping_price, :integer
    add_column :stores, :min_threshold_amount, :integer
  end
end