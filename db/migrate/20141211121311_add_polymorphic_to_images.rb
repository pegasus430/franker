class AddPolymorphicToImages < ActiveRecord::Migration
  def change
    add_column :images, :imageable_id, :integer
    add_column :images, :imageable_type, :string
  end
end