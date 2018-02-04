class AddActiveToLists < ActiveRecord::Migration
  def change
    add_column :lists, :active, :boolean, default: true
  end
end