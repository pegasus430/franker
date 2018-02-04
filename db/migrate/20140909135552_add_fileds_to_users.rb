class AddFiledsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :force_upgrade, :boolean
    add_column :users, :appstore_url, :string
  end
end