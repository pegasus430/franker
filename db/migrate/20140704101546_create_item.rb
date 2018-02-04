class CreateItem < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.string :name
      t.integer :store_id
      t.string :url
      t.integer :price
      t.integer :msrp
      t.string :import_key
      t.integer :image_id
    end
  end
end