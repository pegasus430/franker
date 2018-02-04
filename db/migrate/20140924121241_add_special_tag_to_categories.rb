class AddSpecialTagToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :special_tag, :string
  end
end
