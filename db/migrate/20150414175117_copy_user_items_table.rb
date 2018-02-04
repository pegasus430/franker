class CopyUserItemsTable < ActiveRecord::Migration
  def change
    create_table :user2_items do |t|
      t.integer :user_id
      t.integer :item_id
      t.boolean :favorite
      t.boolean :sale
    end

    add_index :user2_items, [:item_id, :user_id], unique: true
    add_index :user2_items, [:item_id, :user_id, :favorite]

    execute <<-SQL
      DELIMITER $$      
      CREATE TRIGGER user_item_create_trigger AFTER INSERT ON user_items FOR EACH ROW
      BEGIN
        INSERT INTO user2_items (id, user_id, item_id, favorite, sale) VALUES (new.id, new.user_id, new.item_id, new.favorite, new.sale);
      END$$

      CREATE TRIGGER user_item_update_trigger BEFORE UPDATE ON user_items FOR EACH ROW
      BEGIN
        UPDATE user2_items
        SET favorite = NEW.favorite,
        sale = NEW.sale
        WHERE id = OLD.id;
      END$$
      DELIMITER ;
    SQL
  end
end