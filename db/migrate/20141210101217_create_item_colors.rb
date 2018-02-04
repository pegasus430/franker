class CreateItemColors < ActiveRecord::Migration
  def change
    create_table :item_colors do |t|
      t.string :color
      t.integer :item_id
      t.integer :image_id
      t.integer :url
    end
  end
end