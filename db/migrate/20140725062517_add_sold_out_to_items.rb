class AddSoldOutToItems < ActiveRecord::Migration
  def change
    add_column :items, :sold_out, :boolean, default: false
  end
end
