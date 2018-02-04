class AddUserItemsCountToItems < ActiveRecord::Migration
  def self.up
    add_column :items, :user_items_count, :integer, :default => 0

    Item.reset_column_information
    Item.all.each do |p|
      p.update_attribute :user_items_count, p.user_items.length
    end
  end

  def self.down
    remove_column :items, :user_items_count
  end
end
