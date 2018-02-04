class AddFieldsToUserFavoriteStores < ActiveRecord::Migration
  def change
    add_column :user_favorite_stores, :position, :integer, default: 0
    add_column :user_favorite_stores, :favorite, :boolean
  end
end
