class CreateImage < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.string :file_name
      t.string :content_type
      t.string :file_size
    end
  end
end
