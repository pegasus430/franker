class AddFieldsToSalesTax < ActiveRecord::Migration
  def change
    create_table :sales_taxes do |t|
      t.string :zipcode
      t.float :percentage
      t.string :state_code
    end
    add_index :sales_taxes, :id
    add_index :sales_taxes, :zipcode
  end
end
