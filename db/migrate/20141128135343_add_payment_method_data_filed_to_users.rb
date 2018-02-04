class AddPaymentMethodDataFiledToUsers < ActiveRecord::Migration
  def change
    add_column :users, :payment_method_data, :text
  end
end
