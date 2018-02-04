class CreateUserItem < ActiveRecord::Migration
  def change
    create_table :user_items do |t|
      t.integer :user_id
      t.integer :item_id
      t.boolean :favorite
      t.boolean :archive
      t.boolean :seen
    end
  end
end