class AddDescriptionAndUrlToLists < ActiveRecord::Migration
  def change
    add_column :lists, :description, :string
    add_column :lists, :url, :string
  end
end
