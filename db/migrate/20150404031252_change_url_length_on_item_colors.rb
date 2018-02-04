class ChangeUrlLengthOnItemColors < ActiveRecord::Migration
  def change
    change_column :item_colors, :url,  :text
  end
end
