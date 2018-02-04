class ChangeTypeOfMoreInfoInItems < ActiveRecord::Migration
  def change
    change_column :items, :more_info, :text, limit: 16.megabytes
  end
end
