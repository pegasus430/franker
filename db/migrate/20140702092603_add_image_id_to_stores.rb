class AddImageIdToStores < ActiveRecord::Migration
  def change
    add_column :stores, :image_id, :integer
  end
end