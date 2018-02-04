class ChangeFormatForCustomDataInNotifications < ActiveRecord::Migration
  def change
    change_column :notifications, :custom_data, :text
  end
end
