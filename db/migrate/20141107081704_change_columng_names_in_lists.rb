class ChangeColumngNamesInLists < ActiveRecord::Migration
  def change
    rename_column :lists, :description, :designer_name
    rename_column :lists, :url, :designer_url
  end
end
