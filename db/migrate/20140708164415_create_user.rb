class CreateUser < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :uuid
      t.string :imei
      t.datetime :last_activity_at
    end
  end
end