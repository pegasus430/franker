class AddItemsCountToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :items_count, :integer
    Category.all.each do |p|
      # Category.update(p.id, :items_count => p.items.length)
      Category.reset_counters(p.id, :items)
    end

  end
end
