class CreateDoteSettings < ActiveRecord::Migration
  def change
    create_table :dote_settings do |t|
      t.integer :batch_time

      t.timestamps
    end
  end
end
