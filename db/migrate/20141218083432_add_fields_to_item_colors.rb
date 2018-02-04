class AddFieldsToItemColors < ActiveRecord::Migration
  def change
    add_column :item_colors, :rgb, :string
    add_column :item_colors, :sizes, :string
  end
end
