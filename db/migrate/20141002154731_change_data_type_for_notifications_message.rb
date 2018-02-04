class ChangeDataTypeForNotificationsMessage < ActiveRecord::Migration
  def change
    change_column :notifications, :message, :text
  end
end
