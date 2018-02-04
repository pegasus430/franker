class CreateUserLists < ActiveRecord::Migration
  def change
    create_table :user_lists do |t|
      t.integer :user_id
      t.integer :list_id
      t.datetime :seen_at
    end
  end
end
