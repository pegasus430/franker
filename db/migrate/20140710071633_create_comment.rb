class CreateComment < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.string :message
      t.integer :item_id
      t.integer :user_id
    end
  end
end