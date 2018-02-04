class AddImagesToLists < ActiveRecord::Migration
  def change
    add_column :lists, :cover_image, :string
    add_column :lists, :content_square_image, :string
  end
end
