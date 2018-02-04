class CreateCategories < ActiveRecord::Migration
  def change
    create_table :categories do |t|
      t.integer :store_id
      t.integer :parent_id
      t.boolean :overall_category
      t.string :category_type
      t.string :name
      t.text :url
      t.timestamps
    end
  end
end