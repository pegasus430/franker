class AddMoreIndexesForScraping < ActiveRecord::Migration
  def change
    add_index :items, [:store_id, :import_key]
    add_index :items, :category_id
  end
end
