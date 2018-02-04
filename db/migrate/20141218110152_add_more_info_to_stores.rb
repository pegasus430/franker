class AddMoreInfoToStores < ActiveRecord::Migration
  def change
    add_column :stores, :more_info, :boolean, :default => false
  end
end