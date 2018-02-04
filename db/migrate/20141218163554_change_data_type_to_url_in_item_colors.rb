class ChangeDataTypeToUrlInItemColors < ActiveRecord::Migration
  def change
    change_column :item_colors, :url, :string
  end
end
