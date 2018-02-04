class Color < ActiveRecord::Base
  after_update :update_item_color_rgbs

  def update_item_color_rgbs
    @item_colors = ItemColor.where("LOWER(color) = ?", name.downcase)
    if @item_colors.present? && @item_colors.count > 0
      @item_colors.update_all(rgb: hash_value)
    end
  end
end
