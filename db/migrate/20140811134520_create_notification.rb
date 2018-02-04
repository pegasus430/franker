class CreateNotification < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.string  :message
      t.integer :priority
      t.string  :type
      t.boolean :seen
      t.string  :custom_data
    end
    add_reference :notifications, :user, index: true
  end
end