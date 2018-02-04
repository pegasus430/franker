class AddDevTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :dev_token, :string
  end
end
