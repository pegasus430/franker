class AddSaleToUserItems < ActiveRecord::Migration
  def change
    add_column :user_items, :sale, :boolean, default: false
  end
end
