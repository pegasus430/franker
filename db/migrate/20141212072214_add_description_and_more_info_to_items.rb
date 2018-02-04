class AddDescriptionAndMoreInfoToItems < ActiveRecord::Migration
  def change
    add_column :items, :description, :text
    add_column :items, :more_info, :string
    add_column :items, :size, :string
  end
end
