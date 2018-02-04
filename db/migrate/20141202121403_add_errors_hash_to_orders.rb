class AddErrorsHashToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :errors_hash, :text
  end
end
