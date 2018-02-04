class AddPaymentFieldToStores < ActiveRecord::Migration
  def change
    add_column :stores, :payment, :boolean, default: false
  end
end
