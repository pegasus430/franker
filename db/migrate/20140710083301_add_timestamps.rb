class AddTimestamps < ActiveRecord::Migration
  def up
    add_timestamps(:users)
    add_timestamps(:user_items)
    add_timestamps(:comments)
    add_timestamps(:stores)
    add_timestamps(:items)
  end

  def down
    remove_timestamps(:users)
    remove_timestamps(:user_items)
    remove_timestamps(:comments)
    remove_timestamps(:stores)
    remove_timestamps(:items)
  end
end